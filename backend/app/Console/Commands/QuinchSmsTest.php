<?php

namespace App\Console\Commands;

use App\Services\Sms\SmsGateway;
use App\Services\Sms\SmsGatewayFactory;
use Illuminate\Console\Command;
use Throwable;

/**
 * Envoie un VRAI SMS de test pour valider un fournisseur sans passer par une
 * inscription. Exemples :
 *   php artisan quinch:sms-test +221771112233                    (chaîne complète, avec bascule)
 *   php artisan quinch:sms-test +221771112233 --provider=orange  (Orange seul)
 *   php artisan quinch:sms-test +221771112233 --provider=twilio  (Twilio seul)
 */
class QuinchSmsTest extends Command
{
    protected $signature = 'quinch:sms-test
        {phone : Numéro au format international, ex. +221771112233}
        {--provider= : orange | twilio (par défaut : la chaîne configurée, avec bascule)}';

    protected $description = 'Envoie un SMS de test réel pour valider Orange / Twilio';

    public function handle(): int
    {
        $phone = (string) $this->argument('phone');

        if (!preg_match('/^\+[1-9]\d{7,14}$/', $phone)) {
            $this->error('Numéro invalide : utilisez le format international, ex. +221771112233.');

            return self::FAILURE;
        }

        $provider = $this->option('provider');

        if ($provider !== null && !in_array($provider, SmsGatewayFactory::REAL_DRIVERS, true)) {
            $this->error('--provider doit valoir orange ou twilio.');

            return self::FAILURE;
        }

        if ($provider === null && config('services.sms.driver', 'log') === 'log') {
            $this->warn('SMS_DRIVER=log : aucun SMS réel ne sera envoyé (simulation). Utilisez --provider=orange ou twilio.');
        }

        $gateway = $provider ? SmsGatewayFactory::make($provider) : app(SmsGateway::class);
        $label = $provider ?? (string) config('services.sms.driver', 'log');

        $start = microtime(true);

        try {
            $gateway->send($phone, "QUINCH : test d'envoi SMS (aucun code). Vous pouvez ignorer ce message.");
        } catch (Throwable $e) {
            $this->error("Échec ({$label}) : " . preg_replace('#https?://\S+#i', '[url]', $e->getMessage()));

            return self::FAILURE;
        }

        $ms = (int) round((microtime(true) - $start) * 1000);
        $this->info("SMS accepté par « {$label} » en {$ms} ms. Vérifiez la réception sur {$phone}.");

        return self::SUCCESS;
    }
}
