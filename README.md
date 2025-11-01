# S3 Backup Container

Conteneur Docker pour sauvegarder automatiquement des répertoires vers un stockage S3 compatible.

## Fonctionnalités

- Sauvegarde planifiée via cron
- Chiffrement GPG optionnel
- Compatible AWS S3, Wasabi, MinIO
- Compression automatique
- Mode unique ou continu

## Configuration

### Variables essentielles

```bash
# S3 Configuration
AWS_ACCESS_KEY_ID=votre_access_key
AWS_SECRET_ACCESS_KEY=votre_secret_key
AWS_DEFAULT_REGION=eu-west-2
ENDPOINT_URL=https://s3.eu-west-2.wasabisys.com/
BUCKET_NAME=mon-bucket

# Sauvegarde
BACKUP_NAME=ma-sauvegarde
CRON_TIME=02:00
CRON_DOW=1-5  # Lundi à vendredi (optionnel)
RUN_ONCE=true  # Pour exécution unique
```

### Variables optionnelles

- `ENCRYPTION_KEY` : Mot de passe pour chiffrement
- `ENCRYPT_WITH_PUBLIC_KEY_ID` : ID clé GPG publique
- `S3_STORAGE_CLASS` : Classe de stockage S3
- `TRACE` : Mode debug

## Utilisation

### 1. Build de l'image

```bash
docker build -t s3backup .
```

### 2. Exécution

#### Mode unique
```bash
docker run --rm \
  -v /chemin/vers/données:/backup \
  --env-file env \
  -e RUN_ONCE=true \
  s3backup
```

#### Mode continu
```bash
docker run -d \
  --name s3backup \
  -v /chemin/vers/données:/backup \
  --env-file env \
  s3backup
```

#### Avec docker-compose
```yaml
services:
  s3backup:
    build: .
    volumes:
      - /chemin/vers/données:/backup:ro
    env_file: env
    restart: unless-stopped
```

## Chiffrement (optionnel)

### GPG avec clé publique
```bash
ENCRYPT_WITH_PUBLIC_KEY_ID=votre_key_id
```

### Chiffrement par mot de passe
```bash
ENCRYPTION_KEY=votre_mot_de_passe
```

## Logs et dépannage

### Debug
```bash
TRACE=1
docker logs s3backup
```

### Problèmes courants

- **"Please mount a directory to backup"** : Ajoutez `-v /chemin:/backup`
- **Erreurs S3** : Vérifiez les credentials et l'endpoint
- **Clé GPG** : Vérifiez l'ID de clé et la connectivité

### Test
```bash
docker run --rm -v /tmp:/backup --env-file env -e RUN_ONCE=true s3backup
```