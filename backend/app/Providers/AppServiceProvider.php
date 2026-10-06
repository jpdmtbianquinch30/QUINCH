<?php

namespace App\Providers;

use App\Models\Product;
use App\Models\ProductReport;
use App\Models\SiteSetting;
use App\Models\User;
use App\Services\Admin\ContentScreeningService;
use App\Services\Admin\ReportAutomationService;
use App\Services\Sms\SmsGateway;
use App\Services\Sms\SmsGatewayFactory;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        // SMS : SMS_DRIVER = fournisseur principal (log | orange | twilio) et
        // SMS_FALLBACK_DRIVER = secours facultatif (orange | twilio). Avec un
        // vrai fournisseur, l'envoi est suivi (sms_logs) et bascule seul.
        $this->app->bind(SmsGateway::class, fn () => SmsGatewayFactory::fromConfig());
    }

    public function boot(): void
    {
        $this->configureRateLimiting();
        $this->registerPermissionGates();
        $this->registerModerationHooks();
        $this->applySiteSettings();
        $this->registerBadgeHooks();
    }

    /**
     * Badges automatiques : dès qu'un compte change de statut Premium ou KYC, on
     * recalcule SES badges immédiatement (le reste est resynchronisé chaque heure).
     */
    private function registerBadgeHooks(): void
    {
        User::saved(function (User $user) {
            if ($user->wasChanged(['is_premium', 'premium_expires_at', 'kyc_status', 'account_status'])) {
                app(\App\Services\BadgeService::class)->syncUserSafe($user);
            }
        });
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

    /**
     * Une Gate par permission de config/permissions.php.
     * Usage : middleware `permission:users.ban`, ou Gate::allows('users.ban').
     */
    private function registerPermissionGates(): void
    {
        foreach ((array) config('permissions.all', []) as $permission) {
            Gate::define($permission, fn (User $user) => $user->hasPermission($permission));
        }
    }

    /**
     * Automatismes de post-modération (publication immédiate, modération après) :
     *  - masquage automatique d'une annonce signalée par plusieurs comptes distincts
     *  - pré-filtrage (mots interdits, téléphone, lien, doublon, prix aberrant)
     * Tout est protégé par try/catch : une erreur d'automatisme ne doit JAMAIS
     * faire échouer le signalement ou la publication de l'utilisateur.
     */
    private function registerModerationHooks(): void
    {
        ProductReport::created(function (ProductReport $report) {
            try {
                app(ReportAutomationService::class)->onProductReported($report);
            } catch (\Throwable $e) {
                Log::warning('Masquage automatique échoué: ' . $e->getMessage());
            }
        });

        $screen = function (Product $product) {
            try {
                if ($product->user && $product->user->isStaff()) {
                    return;
                }
                app(ContentScreeningService::class)->screenAndStore($product);
            } catch (\Throwable $e) {
                Log::warning('Pré-filtrage échoué: ' . $e->getMessage());
            }
        };

        Product::created($screen);
        Product::updated(function (Product $product) use ($screen) {
            if ($product->wasChanged(['title', 'description', 'price'])) {
                $screen($product);
            }
        });
    }

    /**
     * Les réglages admin (table site_settings, en cache 5 min) surchargent la
     * config .env : interrupteurs de fonctionnalités et boost Premium.
     * Aucun contrôleur existant n'a besoin d'être modifié : ils lisent déjà config().
     */
    private function applySiteSettings(): void
    {
        $settings = SiteSetting::allCached();
        if (!$settings) {
            return;
        }

        $features = [
            'negotiation', 'follow', 'reviews', 'badges', 'sharing',
            'chat_audio', 'chat_file', 'favorites_collections', 'purchases',
        ];

        foreach ($features as $feature) {
            $key = "features.{$feature}";
            if (array_key_exists($key, $settings) && $settings[$key] !== null) {
                config(["quinch.features.{$feature}" => (bool) $settings[$key]]);
            }
        }

        $map = [
            'feed.premium_boost'             => 'quinch.premium.feed_boost',
            'premium.price_monthly'          => 'quinch.premium.prices.monthly',
            'premium.price_annual'           => 'quinch.premium.prices.annual',
            'premium.listing_fee_with_video' => 'quinch.premium.listing_fee_with_video',
        ];

        foreach ($map as $key => $configKey) {
            if (array_key_exists($key, $settings) && $settings[$key] !== null) {
                config([$configKey => (int) $settings[$key]]);
            }
        }
    }
}
