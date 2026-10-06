<?php

namespace App\Support;

/**
 * Contrôle de configuration « fail fast » avant de démarrer en production.
 *
 * Appelé par `php artisan quinch:preflight` (lancé par docker/entrypoint.sh au
 * démarrage de CHAQUE conteneur) : si une seule erreur est trouvée, le
 * conteneur refuse de démarrer plutôt que de tourner avec une configuration
 * dangereuse (SMS non envoyés, CORS ouvert, secret de paiement vide...).
 *
 * Ne contrôle rien hors production.
 */
class ProductionPreflight
{
    /**
     * @return array<int, string> liste des problèmes (vide = tout est bon)
     */
    public function errors(?string $environment = null): array
    {
        $environment ??= (string) app()->environment();

        if ($environment !== 'production') {
            return [];
        }

        $errors = [];

        // ── Application ──
        if (config('app.debug')) {
            $errors[] = 'APP_DEBUG doit être false en production.';
        }
        if (!config('app.key')) {
            $errors[] = 'APP_KEY est vide (php artisan key:generate --show).';
        }
        if (!$this->isPublicHttps((string) config('app.url'))) {
            $errors[] = 'APP_URL doit être une URL https:// publique (pas localhost).';
        }
        if (!$this->isPublicHttps((string) config('quinch.frontend_url'))) {
            $errors[] = 'FRONTEND_URL doit être une URL https:// publique (pas localhost).';
        }

        // ── CORS ──
        $origins = (array) config('cors.allowed_origins', []);
        if ($origins === []) {
            $errors[] = 'CORS_ALLOWED_ORIGINS est vide : le frontend serait bloqué.';
        }
        foreach ($origins as $origin) {
            if ($origin === '*' || preg_match('#(localhost|127\.0\.0\.1)#i', (string) $origin)) {
                $errors[] = "CORS_ALLOWED_ORIGINS contient une origine interdite en production : {$origin}";
            }
        }

        // ── SMS / OTP ──
        $driver = (string) config('services.sms.driver', 'log');
        if (!in_array($driver, ['orange', 'twilio'], true)) {
            $errors[] = "SMS_DRIVER={$driver} : en production il faut 'orange' ou 'twilio' (sinon aucun OTP n'est envoyé).";
        } else {
            array_push($errors, ...$this->smsCredentialErrors($driver));
        }

        $fallback = config('services.sms.fallback_driver');
        if (!$this->blank($fallback)) {
            $fallback = (string) $fallback;
            if (!in_array($fallback, ['orange', 'twilio'], true)) {
                $errors[] = "SMS_FALLBACK_DRIVER={$fallback} : valeurs possibles orange ou twilio.";
            } elseif ($fallback === $driver) {
                $errors[] = 'SMS_FALLBACK_DRIVER doit différer de SMS_DRIVER (sinon pas de vrai secours).';
            } else {
                array_push($errors, ...$this->smsCredentialErrors($fallback));
            }
        }

        // ── File d'attente, cache, base ──
        $queue = (string) config('queue.default');
        if ($queue !== 'redis') {
            $errors[] = "QUEUE_CONNECTION={$queue} : doit valoir redis en production (les workers Docker lisent la file Redis ; sinon les SMS OTP ne partiraient jamais).";
        }
        $cache = (string) config('cache.default');
        if (in_array($cache, ['array', 'null'], true)) {
            $errors[] = "CACHE_STORE={$cache} : les limiteurs de débit et les verrous ne fonctionneraient pas.";
        }
        if ($queue === 'redis' || $cache === 'redis') {
            if ($this->blank(config('database.redis.default.password'))) {
                $errors[] = 'REDIS_PASSWORD est vide alors que Redis est utilisé.';
            }
        }
        if ($this->blank(config('database.connections.pgsql.password'))) {
            $errors[] = 'DB_PASSWORD est vide.';
        }

        // ── Authentification ──
        if (config('sanctum.expiration') === null) {
            $errors[] = 'SANCTUM_TOKEN_EXPIRATION_MINUTES ne doit pas être null (jetons sans expiration).';
        }

        // ── Paiements ──
        $methods = (array) config('quinch.enabled_payment_methods', []);
        if (in_array('wave', $methods, true)) {
            if ($this->blank(config('services.wave.api_key'))) {
                $errors[] = 'WAVE_API_KEY est vide alors que « wave » est activé.';
            }
            if ($this->blank(config('services.wave.webhook_secret'))) {
                $errors[] = 'WAVE_WEBHOOK_SECRET est vide : tous les webhooks Wave seraient rejetés.';
            }
        }
        if (in_array('orange_money', $methods, true)) {
            foreach (['client_id', 'client_secret', 'merchant_key', 'webhook_secret'] as $key) {
                if ($this->blank(config("services.orange_money.{$key}"))) {
                    $errors[] = 'ORANGE_MONEY_' . strtoupper($key) . ' est vide alors que « orange_money » est activé.';
                }
            }
        }
        if (in_array('cash', $methods, true)) {
            $errors[] = "QUINCH_PAYMENT_METHODS ne doit pas contenir « cash » en production.";
        }

        return $errors;
    }

    /** @return array<int, string> */
    private function smsCredentialErrors(string $driver): array
    {
        $errors = [];

        if ($driver === 'orange') {
            foreach (['client_id', 'client_secret', 'sender'] as $key) {
                if ($this->blank(config("services.sms.orange.{$key}"))) {
                    $errors[] = 'ORANGE_SMS_' . strtoupper($key) . ' est vide.';
                }
            }
            $sender = (string) config('services.sms.orange.sender');
            if ($sender !== '' && !preg_match('/^\+\d{8,15}$/', $sender)) {
                $errors[] = "ORANGE_SMS_SENDER invalide (format +221XXXXXXXXX) : {$sender}";
            }
        }

        if ($driver === 'twilio') {
            if ($this->blank(config('services.sms.twilio.sid')) || $this->blank(config('services.sms.twilio.token'))) {
                $errors[] = 'TWILIO_SID / TWILIO_TOKEN sont vides.';
            }
            if ($this->blank(config('services.sms.twilio.from')) && $this->blank(config('services.sms.twilio.messaging_service_sid'))) {
                $errors[] = 'TWILIO_FROM (ou TWILIO_MESSAGING_SERVICE_SID) est vide.';
            }
        }

        return $errors;
    }

    private function blank(mixed $value): bool
    {
        return !is_string($value) || trim($value) === '' || strtolower(trim($value)) === 'null';
    }

    private function isPublicHttps(string $url): bool
    {
        if (!str_starts_with($url, 'https://')) {
            return false;
        }

        $host = (string) parse_url($url, PHP_URL_HOST);

        return $host !== '' && !preg_match('/^(localhost|127\.|0\.0\.0\.0)/i', $host);
    }
}
