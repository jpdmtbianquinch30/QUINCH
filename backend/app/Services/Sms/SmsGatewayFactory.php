<?php

namespace App\Services\Sms;

use App\Models\SmsLog;
use Illuminate\Support\Facades\Log;
use InvalidArgumentException;

class SmsGatewayFactory
{
    /** Fournisseurs réels (le driver « log » est réservé au développement). */
    public const REAL_DRIVERS = ['orange', 'twilio'];

    /** Passerelle d'UN fournisseur donné, sans bascule. */
    public static function make(string $driver): SmsGateway
    {
        return match ($driver) {
            'orange' => new OrangeSmsGateway(),
            'twilio' => new TwilioSmsGateway(),
            'log'    => new LogSmsGateway(),
            default  => throw new InvalidArgumentException("Fournisseur SMS inconnu : {$driver}"),
        };
    }

    /**
     * Passerelle de l'application, selon la configuration :
     * SMS_DRIVER (principal) et SMS_FALLBACK_DRIVER (secours, facultatif).
     * « log » (ou une valeur inconnue) reste le simulateur de développement.
     */
    public static function fromConfig(): SmsGateway
    {
        $primary = (string) config('services.sms.driver', 'log');

        if (!in_array($primary, self::REAL_DRIVERS, true)) {
            return new LogSmsGateway();
        }

        $gateways = [$primary => self::make($primary)];

        $fallback = config('services.sms.fallback_driver');
        if (is_string($fallback) && $fallback !== $primary && in_array($fallback, self::REAL_DRIVERS, true)) {
            $gateways[$fallback] = self::make($fallback);
        }

        return new ResilientSmsGateway($gateways, new CacheSmsProviderBreaker(), self::recorder());
    }

    /**
     * Enregistre chaque tentative : table sms_logs + journal applicatif.
     * Numéro masqué ; ni le texte du SMS ni le code OTP ne sont jamais écrits.
     */
    public static function recorder(): callable
    {
        return function (string $provider, bool $ok, string $to, ?string $error, int $durationMs): void {
            $masked = substr($to, 0, 6) . '***' . substr($to, -2);

            if ($ok) {
                Log::info('SMS envoyé', ['provider' => $provider, 'to' => $masked, 'ms' => $durationMs]);
            } else {
                Log::error('SMS en échec', ['provider' => $provider, 'to' => $masked, 'error' => $error, 'ms' => $durationMs]);
            }

            SmsLog::create([
                'provider'    => $provider,
                'status'      => $ok ? 'sent' : 'failed',
                'to_masked'   => $masked,
                'error'       => $error,
                'duration_ms' => $durationMs,
                'created_at'  => now(),
            ]);
        };
    }
}
