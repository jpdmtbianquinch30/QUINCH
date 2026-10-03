<?php

namespace App\Services\Sms;

use Illuminate\Support\Facades\Log;

/**
 * Driver de développement : écrit le SMS dans storage/logs/laravel.log.
 * En production il n'écrit JAMAIS le contenu (le code OTP) dans les logs.
 */
class LogSmsGateway implements SmsGateway
{
    public function send(string $to, string $message): void
    {
        if (app()->isProduction()) {
            Log::warning('SMS_DRIVER=log en production : aucun SMS réel envoyé. Configurez orange ou twilio.', [
                'to' => substr($to, 0, 6) . '***' . substr($to, -2),
            ]);

            return;
        }

        Log::info("[SMS simulé] {$to} : {$message}");
    }
}
