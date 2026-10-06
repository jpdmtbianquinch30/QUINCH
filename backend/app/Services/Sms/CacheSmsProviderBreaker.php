<?php

namespace App\Services\Sms;

use Illuminate\Support\Facades\Cache;

/**
 * Disjoncteur stocké dans le cache (Redis en production) : partagé entre tous
 * les workers de file d'attente.
 */
class CacheSmsProviderBreaker implements SmsProviderBreaker
{
    public function isOpen(string $provider): bool
    {
        return Cache::has($this->key($provider));
    }

    public function trip(string $provider): void
    {
        Cache::put($this->key($provider), 1, max(10, (int) config('services.sms.breaker_seconds', 120)));
    }

    public function clear(string $provider): void
    {
        Cache::forget($this->key($provider));
    }

    private function key(string $provider): string
    {
        return "sms:breaker:{$provider}";
    }
}
