# S3 Backup Container

## Description

Ce projet fournit un conteneur Docker permettant de sauvegarder automatiquement des répertoires vers un stockage S3 compatible (AWS S3, Wasabi, MinIO, etc.). Le conteneur supporte la planification via cron, le chiffrement GPG et peut fonctionner en mode unique ou continu.

## Fonctionnalités

- ✅ **Sauvegarde automatisée** : Planification via cron avec support des jours de semaine et du mois
- 🔐 **Chiffrement** : Support du chiffrement GPG avec clé publique ou mot de passe
- 🌐 **Compatibilité S3** : Fonctionne avec AWS S3, Wasabi, MinIO et autres services compatibles S3
- 📦 **Compression** : Création d'archives tar.gz compressées
- ⚡ **Mode flexible** : Exécution unique ou continue
- 🐳 **Containerisé** : Déploiement facile avec Docker

## Configuration

### Variables d'environnement

#### Configuration AWS/S3 (obligatoire)
- `AWS_ACCESS_KEY_ID` : Clé d'accès AWS/S3
- `AWS_SECRET_ACCESS_KEY` : Clé secrète AWS/S3  
- `AWS_DEFAULT_REGION` : Région AWS (ex: eu-west-2)
- `BUCKET_NAME` : Nom du bucket S3 de destination
- `ENDPOINT_URL` : URL du service S3 (pour services non-AWS comme Wasabi)

#### Configuration de la sauvegarde
- `BACKUP_NAME` : Nom de base pour les fichiers de sauvegarde (défaut: "backup")
- `CRON_TIME` : Heure d'exécution au format HH:MM (défaut: "02:00")
- `CRON_DOW` : Jour de la semaine (1-7, lundi=1) - optionnel
- `CRON_DOM` : Jour du mois (1-31) - optionnel
- `RUN_ONCE` : Si "true", exécute une seule sauvegarde puis s'arrête

#### Configuration avancée (optionnel)
- `S3_STORAGE_CLASS` : Classe de stockage S3 (ex: STANDARD_IA, GLACIER)
- `AWS_SIGNATURE_VERSION` : Version de signature AWS (ex: s3v4)
- `ENCRYPT_WITH_PUBLIC_KEY_ID` : ID de clé publique GPG pour chiffrement
- `ENCRYPTION_KEY` : Mot de passe pour chiffrement symétrique
- `KEYSERVER` : Serveur de clés GPG (défaut: hkp://keyserver.ubuntu.com)
- `TRACE` : Active le mode debug si défini

### Formats de planification cron

Les variables `CRON_DOW` et `CRON_DOM` supportent plusieurs formats :
- **Valeur unique** : `3` (mercredi pour DOW, 3ème jour pour DOM)
- **Plage** : `1-5` (lundi à vendredi pour DOW)
- **Liste** : `1,3,5` (lundi, mercredi, vendredi pour DOW)

## Utilisation

### 1. Configuration de base

Copiez et modifiez le fichier `env` avec vos paramètres :

```bash
# Configuration S3
AWS_ACCESS_KEY_ID=votre_access_key
AWS_SECRET_ACCESS_KEY=votre_secret_key
AWS_DEFAULT_REGION=eu-west-2
ENDPOINT_URL=https://s3.eu-west-2.wasabisys.com/
BUCKET_NAME=mon-bucket/mon-dossier

# Configuration sauvegarde
BACKUP_NAME=ma-sauvegarde
CRON_TIME=02:00
CRON_DOW=1-5  # Lundi à vendredi
```

### 2. Construction de l'image Docker

```bash
cd /srv/bck/s3backup
docker build -t s3backup:latest .
```

### 3. Exécution

#### Mode unique (une sauvegarde puis arrêt)
```bash
docker run --rm \
  -v /chemin/vers/données:/backup \
  --env-file env \
  -e RUN_ONCE=true \
  s3backup:latest
```

#### Mode continu (planification cron)
```bash
docker run -d \
  --name s3backup \
  -v /chemin/vers/données:/backup \
  --env-file env \
  s3backup:latest
```

### 4. Exemple avec docker-compose

```yaml
services:
  s3backup:
    build: .
    container_name: s3backup
    volumes:
      - /chemin/vers/données:/backup:ro
    env_file:
      - env
    restart: unless-stopped
```

## Chiffrement

### Chiffrement avec clé publique GPG

1. Générez une paire de clés GPG :
```bash
gpg --gen-key
```

2. Obtenez l'ID de la clé publique :
```bash
gpg --list-keys
```

3. Configurez la variable d'environnement :
```bash
ENCRYPT_WITH_PUBLIC_KEY_ID=votre_key_id
```

### Chiffrement symétrique

Configurez simplement la variable :
```bash
ENCRYPTION_KEY=votre_mot_de_passe_fort
```

## Format des fichiers de sauvegarde

Les fichiers sont nommés selon le format :
- **Non chiffrés** : `{BACKUP_NAME}-{TIMESTAMP}.tgz`
- **Chiffrés** : `{BACKUP_NAME}-{TIMESTAMP}.tgz.gpg`

Où `{TIMESTAMP}` est au format `YYYY-MM-DD-HH-MM-SS` (UTC).

## Logs et débogage

### Activation du mode debug
```bash
TRACE=1
```

### Vérification des logs
```bash
docker logs s3backup
```

### Messages typiques
- `Starting backup at [timestamp]` : Début de sauvegarde
- `The backup for [name] finished successfully` : Sauvegarde réussie
- `Backup of backup/ has failed` : Échec de sauvegarde

## Dépannage

### Problèmes courants

#### "Please mount a directory to backup"
- **Cause** : Le répertoire `/backup` n'est pas monté
- **Solution** : Ajoutez `-v /chemin/source:/backup` à la commande docker

#### "Failed to retrieve the public key"
- **Cause** : Clé GPG introuvable ou serveur de clés inaccessible  
- **Solution** : Vérifiez l'ID de clé et la connectivité au serveur

#### Erreurs de connexion S3
- **Cause** : Credentials incorrects ou endpoint inaccessible
- **Solution** : Vérifiez les variables AWS_* et ENDPOINT_URL

### Test de configuration

Utilisez `RUN_ONCE=true` pour tester votre configuration :
```bash
docker run --rm \
  -v /tmp/test:/backup \
  --env-file env \
  -e RUN_ONCE=true \
  s3backup:latest
```

## Sécurité

- 🔑 **Stockage des credentials** : Utilisez des fichiers `.env` avec permissions restrictives (600)
- 🔐 **Chiffrement recommandé** : Activez toujours le chiffrement pour les données sensibles
- 🚫 **Pas de logs de credentials** : Les clés ne sont pas affichées dans les logs
- 📦 **Conteneur minimal** : Image Alpine légère avec packages essentiels uniquement