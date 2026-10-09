#!/usr/bin/env bash
# Sauvegarde PostgreSQL de QUINCH : dump, vérification, chiffrement optionnel, copie hors serveur, rotation.
#
# Usage (depuis la racine du projet, sur le serveur) :
#   ./scripts/backup/backup.sh
# Planification (cron, tous les jours à 03h00) :
#   0 3 * * * cd /opt/quinch && ./scripts/backup/backup.sh >> /var/log/quinch-backup.log 2>&1
#
# Réglages (variables d'environnement, toutes optionnelles) :
#   BACKUP_DIR            dossier local des sauvegardes            (défaut : /var/backups/quinch)
#   BACKUP_KEEP_DAILY     nombre de sauvegardes locales gardées    (défaut : 14)
#   BACKUP_AGE_RECIPIENT  clé PUBLIQUE age : chiffre le dump (recommandé : il contient des données personnelles)
#   RCLONE_REMOTE         destination hors serveur, ex. contabo:quinch-backups (rclone configuré au préalable)
#   REMOTE_KEEP_DAYS      âge maximal des sauvegardes hors serveur (défaut : 30)
#   COMPOSE               commande compose                          (défaut : docker compose)
#
# La durée de conservation (≈ 30 jours) est un choix de conformité : une donnée supprimée par un
# utilisateur reste dans les sauvegardes jusqu'à leur expiration (voir docs/BACKUPS.md).
set -euo pipefail

cd "$(dirname "$0")/../.."

COMPOSE="${COMPOSE:-docker compose}"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/quinch}"
BACKUP_KEEP_DAILY="${BACKUP_KEEP_DAILY:-14}"
REMOTE_KEEP_DAYS="${REMOTE_KEEP_DAYS:-30}"

# Identifiants de la base : le .env racine (lu par docker-compose.yml).
if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  . ./.env
  set +a
fi
: "${POSTGRES_USER:?POSTGRES_USER manquant (fichier .env)}"
: "${POSTGRES_DB:?POSTGRES_DB manquant (fichier .env)}"

mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

stamp="$(date +%Y%m%d-%H%M%S)"
file="$BACKUP_DIR/quinch-$stamp.dump"

echo "[$(date -Is)] Sauvegarde de $POSTGRES_DB..."

# Format « custom » (-Fc) : compressé, restaurable table par table avec pg_restore.
$COMPOSE exec -T postgres pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc --no-owner > "$file"

# Contrôle d'intégrité : pg_restore doit pouvoir lister le contenu du dump.
if ! $COMPOSE exec -T postgres pg_restore --list < "$file" > /dev/null; then
  echo "ERREUR : le dump est illisible, sauvegarde abandonnée." >&2
  rm -f "$file"
  exit 1
fi

size="$(du -h "$file" | cut -f1)"

# Chiffrement (age) : la clé privée reste HORS du serveur ; seul le destinataire public est ici.
if [ -n "${BACKUP_AGE_RECIPIENT:-}" ]; then
  if ! command -v age > /dev/null 2>&1; then
    echo "ERREUR : BACKUP_AGE_RECIPIENT défini mais « age » n'est pas installé." >&2
    rm -f "$file"
    exit 1
  fi
  age -r "$BACKUP_AGE_RECIPIENT" -o "$file.age" "$file"
  rm -f "$file"
  file="$file.age"
else
  echo "AVERTISSEMENT : sauvegarde NON chiffrée (définir BACKUP_AGE_RECIPIENT)." >&2
fi

sha256sum "$file" | cut -d' ' -f1 > "$file.sha256"
echo "[$(date -Is)] OK : $file ($size avant chiffrement)"

# Copie hors serveur (une sauvegarde sur le même disque que la base ne protège pas d'une perte du serveur).
if [ -n "${RCLONE_REMOTE:-}" ]; then
  rclone copy "$file" "$RCLONE_REMOTE" --quiet
  rclone copy "$file.sha256" "$RCLONE_REMOTE" --quiet
  rclone delete "$RCLONE_REMOTE" --min-age "${REMOTE_KEEP_DAYS}d" --quiet
  echo "[$(date -Is)] Copie hors serveur : $RCLONE_REMOTE (conservation ${REMOTE_KEEP_DAYS} jours)"
else
  echo "AVERTISSEMENT : aucune copie hors serveur (définir RCLONE_REMOTE)." >&2
fi

# Rotation locale : on garde les N plus récentes.
ls -1t "$BACKUP_DIR"/quinch-*.dump* 2> /dev/null | grep -v '\.sha256$' | tail -n +"$((BACKUP_KEEP_DAILY + 1))" | while read -r old; do
  rm -f "$old" "$old.sha256"
done
