<?php

namespace App\Providers;

use App\Services\Sms\LogSmsGateway;
use App\Services\Sms\OrangeSmsGateway;
use App\Services\Sms\SmsGateway;
use App\Services\Sms\TwilioSmsGateway;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        // Fournisseur SMS choisi par SMS_DRIVER : log (dev) | orange | twilio
        $this->app->bind(SmsGateway::class, function () {
            return match (config('services.sms.driver', 'log')) {
                'orange' => new OrangeSmsGateway(),
                'twilio' => new TwilioSmsGateway(),
                default  => new LogSmsGateway(),
            };
        });
    }

    public function boot(): void
    {
        $this->configureRateLimiting();
    }

    /**
     * Limiteur GLOBAL de l'API, en plus des throttle ciblés (login, OTP, achat...).
     * - Connecté : plafond par compte (pas par IP : NAT mobile).
     * - Anonyme : plafond par IP.
     */
    private function configureRateLimiting(): void
    {
        RateLimiter::for('api', function (Request $request) {
            // Exemptions : webhooks de paiement (protégés par signature HMAC,
            // ne jamais en perdre un) et flux vidéo (nombreuses requêtes Range).
            if ($request->is('api/v1/webhooks/*', 'api/v1/videos/*')) {
                return Limit::none();
            }

            $user = $request->user('sanctum');

            if ($user) {
                return Limit::perMinute((int) config('quinch.rate_limits.authenticated', 300))
                    ->by('user:' . $user->getAuthIdentifier());
            }

            return Limit::perMinute((int) config('quinch.rate_limits.guest', 200))
                ->by('ip:' . $request->ip());
        });
    }
}
