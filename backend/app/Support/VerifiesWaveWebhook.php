<?php

namespace App\Support;

trait VerifiesWaveWebhook
{
    /**
     * Secret de signature des webhooks Wave (WAVE_WEBHOOK_SECRET).
     * Vide ou absent => null => le webhook est rejeté par les contrôleurs.
     * Il n'existe aucun secret par défaut.
     */
    private function waveWebhookSecret(): ?string
    {
        $secret = config('services.wave.webhook_secret');

        return is_string($secret) && trim($secret) !== '' ? $secret : null;
    }

    private function verifyWaveSignature(string $header, string $body, string $secret): bool
    {
        $parts = collect(explode(',', $header))->mapWithKeys(function ($part) {
            [$key, $value] = array_pad(explode('=', $part, 2), 2, null);
            return [$key => $value];
        });

        $timestamp = $parts->get('t');
        $signature = $parts->get('v1');

        if (!$timestamp || !$signature || abs(time() - (int) $timestamp) > 300) {
            return false;
        }

        return hash_equals(hash_hmac('sha256', $timestamp . $body, $secret), $signature);
    }
}