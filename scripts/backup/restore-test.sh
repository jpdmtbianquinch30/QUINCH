#!/usr/bin/env bash
# Test de restauration : restaure une sauvegarde dans une base TEMPORAIRE, vérifie son contenu, la supprime.
# Une sauvegarde qu'on n'a jamais restaurée n'est pas une sauvegarde : à faire au moins une fois par mois.
#
# Usage :
#   ./scripts/backup/restore-test.sh /var/backups/quinch/quinch-20261008-030000.dump
#   AGE_IDENTITY=/chemin/cle-privee.txt ./scripts/backup/restore-test.sh fichier.dump.age
#
# Ne touche JAMAIS à la base de production : tout se passe dans « quinch_restore_test ».
set -euo pipefail

cd "$(dirname "$0")/../.."

COMPOSE="${COMPOSE:-docker compose}"
DUMP="${1:?Usage : $0 <fichier.dump | fichier.dump.age>}"
TEMP_DB="quinch_restore_test"

if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  . ./.env
  set +a
fi
: "${POSTGRES_USER:?POSTGRES_USER manquant (fichier .env)}"

work="$DUMP"
cleanup() {
  [ "$work" != "$DUMP" ] && rm -f "$work"
  $COMPOSE exec -T postgres dropdb -U "$POSTGRES_USER" --if-exists "$TEMP_DB" > /dev/null 2>&1 || true
}
trap cleanup EXIT

# Vérification de l'empreinte si elle existe.
if [ -f "$DUMP.sha256" ]; then
  expected="$(cat "$DUMP.sha256")"
  actual="$(sha256sum "$DUMP" | cut -d' ' -f1)"
  [ "$expected" = "$actual" ] || { echo "ERREUR : empreinte différente, fichier corrompu." >&2; exit 1; }
  echo "Empreinte SHA-256 : OK"
fi

# Déchiffrement.
case "$DUMP" in
  *.age)
    : "${AGE_IDENTITY:?AGE_IDENTITY (fichier de clé privée age) manquant}"
    work="$(mktemp)"
    age -d -i "$AGE_IDENTITY" -o "$work" "$DUMP"
    ;;
esac

echo "Création de la base temporaire $TEMP_DB..."
$COMPOSE exec -T postgres dropdb -U "$POSTGRES_USER" --if-exists "$TEMP_DB" > /dev/null
$COMPOSE exec -T postgres createdb -U "$POSTGRES_USER" "$TEMP_DB"

echo "Restauration..."
$COMPOSE exec -T postgres pg_restore -U "$POSTGRES_USER" -d "$TEMP_DB" --no-owner --exit-on-error < "$work"

q() { $COMPOSE exec -T postgres psql -U "$POSTGRES_USER" -d "$TEMP_DB" -tA -c "$1"; }

users="$(q 'select count(*) from users')"
products="$(q 'select count(*) from products')"
migrations="$(q 'select count(*) from migrations')"
last="$(q 'select migration from migrations order by id desc limit 1')"

echo "Utilisateurs : $users | Annonces : $products | Migrations : $migrations (dernière : $last)"

if [ "$migrations" -lt 1 ]; then
  echo "ERREUR : aucune migration dans la base restaurée, la sauvegarde est inutilisable." >&2
  exit 1
fi

echo "OK : la sauvegarde est restaurable."
