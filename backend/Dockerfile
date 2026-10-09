# syntax=docker/dockerfile:1

# ─── Étape 1 : dépendances Composer ──────────────────────────────────────────
FROM composer:2 AS vendor
WORKDIR /app
COPY backend/composer.json backend/composer.lock ./
RUN composer install --no-dev --no-scripts --no-autoloader --prefer-dist --no-interaction
COPY backend/ ./
RUN composer dump-autoload --optimize --no-dev

# ─── Étape 2 : image PHP-FPM finale ──────────────────────────────────────────
FROM php:8.3-fpm-alpine

# docker-php-extension-installer : installe des binaires precompiles/optimises
# quand possible, beaucoup plus rapide et fiable que "docker-php-ext-install"
# pur (qui recompile tout depuis les sources, y compris opcache+JIT qui est
# notoirement lent a compiler sur Alpine/musl).
# Version ET empreinte épinglées : un « latest » compromis ne peut plus entrer dans l'image.
ADD --chmod=0755 --checksum=sha256:3f49c71fa66c79b8b2b96bc0ce92885dafd7946f3b5a46f545b390d6f1617e2c https://github.com/mlocati/docker-php-extension-installer/releases/download/2.12.0/install-php-extensions /usr/local/bin/

# ffmpeg : nécessaire à ProcessVideoJob. redis : cache, files d'attente, limiteur.
RUN apk add --no-cache libpq ffmpeg \
    && install-php-extensions pdo_pgsql gd zip intl mbstring bcmath opcache redis pcntl

# Config PHP de production : pas d'exposition d'infos sensibles, opcache actif
COPY docker/php/production.ini /usr/local/etc/php/conf.d/zz-quinch.ini

# Pool PHP-FPM dimensionné par variables d'environnement.
COPY backend/docker/php/zz-quinch-fpm.conf /usr/local/etc/php-fpm.d/zz-quinch-fpm.conf
ENV PHP_FPM_MAX_CHILDREN=30 \
    PHP_FPM_START_SERVERS=6 \
    PHP_FPM_MIN_SPARE=4 \
    PHP_FPM_MAX_SPARE=10

WORKDIR /var/www/html

COPY --from=vendor /app ./
COPY backend/ ./

RUN mkdir -p storage/framework/{sessions,views,cache} storage/logs bootstrap/cache \
    && chown -R www-data:www-data storage bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache

# L'autoload optimisé est déjà généré dans l'étape « vendor » ;
# Composer n'est volontairement pas dans l'image finale.
RUN (php artisan package:discover --ansi || true) \
    && chown -R www-data:www-data bootstrap/cache storage

# Ne jamais committer/copier un .env réel dans l'image : il est injecté au
# lancement du conteneur via env_file dans docker-compose.yml.

# Entrypoint : contrôle de configuration (quinch:preflight), mise en cache
# config/routes/vues, migrations optionnelles (RUN_MIGRATIONS=true), puis
# exécution de la commande du conteneur (php-fpm, queue:work, schedule:work).
COPY backend/docker/entrypoint.sh /usr/local/bin/quinch-entrypoint
RUN sed -i 's/\r$//' /usr/local/bin/quinch-entrypoint && chmod +x /usr/local/bin/quinch-entrypoint

EXPOSE 9000
ENTRYPOINT ["quinch-entrypoint"]
CMD ["php-fpm"]
