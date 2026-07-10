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
ADD --chmod=0755 https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/

RUN apk add --no-cache libpq \
    && install-php-extensions pdo_pgsql gd zip intl mbstring bcmath opcache

# Config PHP de production : pas d'exposition d'infos sensibles, opcache actif
COPY docker/php/production.ini /usr/local/etc/php/conf.d/zz-quinch.ini

WORKDIR /var/www/html

COPY --from=vendor /app ./
COPY backend/ ./

RUN mkdir -p storage/framework/{sessions,views,cache} storage/logs bootstrap/cache \
    && chown -R www-data:www-data storage bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache

# Regénère bootstrap/cache/packages.php à partir du vendor/ réellement présent
# dans l'image (--no-dev) : évite qu'un cache généré en local (avec des
# dépendances dev comme laravel/pail) ne fasse planter l'app en prod avec une
# erreur "Class ... not found".
RUN composer dump-autoload --optimize --no-dev \
    && php artisan package:discover --ansi || true

# Ne jamais committer/copier un .env réel dans l'image : il est injecté au
# lancement du conteneur via env_file dans docker-compose.yml.

EXPOSE 9000
CMD ["php-fpm"]
