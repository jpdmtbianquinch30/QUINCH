#!/bin/sh
# Entrypoint commun à tous les conteneurs Laravel (app, queue, queue_videos, scheduler).
set -e
cd /var/www/html

if [ "${APP_ENV}" = "production" ]; then
    # 1) Refuse de démarrer si la configuration est dangereuse.
    php artisan quinch:preflight

    # 2) Caches de production (config lue UNE fois : env() ne marche plus ensuite).
    php artisan config:cache
    php artisan route:cache
    php artisan event:cache
    php artisan view:cache
fi

# 3) Migrations : uniquement sur le service qui porte RUN_MIGRATIONS=true (app).
if [ "${RUN_MIGRATIONS:-false}" = "true" ]; then
    php artisan migrate --force
fi

# Si on est root (php-fpm), les fichiers générés ci-dessus doivent rester
# lisibles/écrivables par www-data. On évite un chown récursif sur le volume
# médias (trop lent) : seulement les dossiers de travail de Laravel.
if [ "$(id -u)" = "0" ]; then
    chown -R www-data:www-data storage/framework storage/logs bootstrap/cache 2>/dev/null || true
fi

# Marqueur lu par le healthcheck du service app (docker-compose.yml).
touch /tmp/quinch-ready

exec "$@"
