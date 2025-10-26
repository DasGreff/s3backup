#!/bin/bash

set -eo pipefail
[[ -n "$TRACE" ]] && set -x

CRON_TIME="${CRON_TIME:-"02:00"}"
CRON_DOW="${CRON_DOW:-""}"
CRON_DOM="${CRON_DOM:-""}"
# CRON_TIME au format HH:MM
cron_hour="${CRON_TIME%:*}"
cron_minute="${CRON_TIME#*:}"

echo "Params - CRON_TIME: $CRON_TIME, CRON_DOW: $CRON_DOW, CRON_DOM: $CRON_DOM"

# Fonction pour matcher une valeur cron (unique, plage, liste)
cron_value_match() {
  local expr="$1"
  local val="$2"
  if [[ "$expr" =~ ^[0-9]+$ ]]; then
    [[ "$val" == "$expr" ]] && return 0 || return 1
  elif [[ "$expr" =~ ^[0-9]+-[0-9]+$ ]]; then
    local start=${expr%-*}
    local end=${expr#*-}
    (( val >= start && val <= end )) && return 0 || return 1
  elif [[ "$expr" =~ ^([0-9]+,)+[0-9]+$ ]]; then
    IFS=',' read -ra arr <<< "$expr"
    for i in "${arr[@]}"; do
      [[ "$val" == "$i" ]] && return 0
    done
    return 1
  else
    return 1
  fi
}

while true; do
  # Heure courante
  now_hour=$(date +"%H")
  now_minute=$(date +"%M")
  now_dow=$(date +"%u")
  now_dom=$(date +"%d")

  # Si RUN_ONCE=true, on bypass le test de l'heure et on lance le backup immédiatement
  if [[ "$RUN_ONCE" == "true" ]]; then
    echo "RUN_ONCE=true détecté, lancement immédiat du backup."
    RUN_BACKUP=1
  else
    RUN_BACKUP=0
    # Vérification heure/minute
    if [[ "$now_hour" == "$cron_hour" && "$now_minute" == "$cron_minute" ]]; then
      # Vérification jour de semaine OU jour du mois
      if { [[ -n "$CRON_DOW" && "$CRON_DOW" != "*" ]] && cron_value_match "$CRON_DOW" "$now_dow"; } || \
         { [[ -n "$CRON_DOM" && "$CRON_DOM" != "*" ]] && cron_value_match "$CRON_DOM" "$now_dom"; }; then
        RUN_BACKUP=1
      fi
    fi
  fi

  if (( RUN_BACKUP == 1 )); then
    # Check if backup directory exists
    if [[ ! -d "/backup" ]]; then
      echo "Please mount a directory to backup with -v /backup:/backup"
      exit 1
    fi

    echo "Starting backup at $(date)"
    
    # Set default values for Amazon S3 info
    AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-null}"
    AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-null}"
    AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-null}"

    BACKUP_NAME="${BACKUP_NAME:-backup}"
    BUCKET_NAME="${BUCKET_NAME:-null}"

    # Set default keyserver (Ubuntu keyserver)
    KEYSERVER="${KEYSERVER:-hkp://keyserver.ubuntu.com}"

    # Set timestamp for backup
    TIMESTAMP="$(date -u "+%Y-%m-%d-%H-%M-%S")"

    # Build endpoint parameter if endpoint given
    if [[ -n "$ENDPOINT_URL" ]]; then
      ENDPOINT_URL_PARAMETER="--endpoint-url=$ENDPOINT_URL"
    fi

    # Add the StorageClass parameter if specified
    if [[ -n "$S3_STORAGE_CLASS" ]]; then
      S3_STORAGE_CLASS_PARAMETER="--storage-class=$S3_STORAGE_CLASS"
    fi

    # Setup AWS signature version if specified
    if [[ -n "$AWS_SIGNATURE_VERSION" ]]; then
      aws configure set default.s3.signature_version "$AWS_SIGNATURE_VERSION"
    fi

    # Set target directory for backup
    TARGET="backup/"

    # Function to create a tar archive of the target directory
    create_tar_archive() {
      tar --create --gzip --file - "$TARGET"
    }

    # Function to encrypt the input stream
    encrypt_stream() {
      if [[ "$1" == "public_key" ]]; then
        gpg --batch --no-tty --quiet --encrypt --always-trust --recipient "$ENCRYPT_WITH_PUBLIC_KEY_ID"
      elif [[ "$1" == "encryption_key" ]]; then
        gpg --batch --no-tty --quiet --symmetric --cipher-algo AES256 --passphrase "$ENCRYPTION_KEY"
      else
        cat
      fi
    }

    # Function to upload backup to S3
    upload_to_s3() {
      if [[ "$1" == "encrypted" ]]; then
        # shellcheck disable=SC2086
        aws $ENDPOINT_URL_PARAMETER s3 cp - "s3://$BUCKET_NAME/$BACKUP_NAME-$TIMESTAMP.tgz.gpg" $S3_STORAGE_CLASS_PARAMETER
      else
        # shellcheck disable=SC2086
        aws $ENDPOINT_URL_PARAMETER s3 cp - "s3://$BUCKET_NAME/$BACKUP_NAME-$TIMESTAMP.tgz" $S3_STORAGE_CLASS_PARAMETER
      fi
    }

    # Perform backup based on encryption method
    if [[ -n "$ENCRYPT_WITH_PUBLIC_KEY_ID" ]]; then
      if gpg --quiet --keyserver "$KEYSERVER" --recv-keys "$ENCRYPT_WITH_PUBLIC_KEY_ID"; then
        if create_tar_archive | encrypt_stream "public_key" | upload_to_s3 "encrypted"; then
          echo "$TIMESTAMP: The backup for $BACKUP_NAME finished successfully."
        else
          echo "Backup of $TARGET has failed. Please investigate the issue."
          exit 1
        fi
      else
        echo "Error: Failed to retrieve the public key from the keyserver."
        exit 1
      fi
    elif [[ -n "$ENCRYPTION_KEY" ]]; then
      if create_tar_archive | encrypt_stream "encryption_key" | upload_to_s3 "encrypted"; then
        echo "$TIMESTAMP: The backup for $BACKUP_NAME finished successfully."
      else
        echo "Backup of $TARGET has failed. Please investigate the issue."
        exit 1
      fi
    else
      if create_tar_archive | encrypt_stream "no_encryption" | upload_to_s3 "unencrypted"; then
        echo "$TIMESTAMP: The backup for $BACKUP_NAME finished successfully."
      else
        echo "Backup of $TARGET has failed. Please investigate the issue."
        exit 1
      fi
    fi
    # Si RUN_ONCE=true, on sort de la boucle après la première exécution
    if [[ "$RUN_ONCE" == "true" ]]; then
      echo "RUN_ONCE=true détecté, sortie du script après une exécution."
      exit 0
    fi
    sleep 60
  fi
  sleep 60
done