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

    /**
     * En-tête Wave-Signature : « t=<horodatage>,v1=<hmac>[,v1=<hmac>...] ».
     * Plusieurs signatures v1 peuvent coexister (rotation de secret) : une seule
     * valide suffit. L'horodatage doit rester dans une fenêtre de 5 minutes.
     */
    private function verifyWaveSignature(string $header, string $body, string $secret): bool
    {
        $timestamp = null;
        $signatures = [];

        foreach (explode(',', $header) as $part) {
            [$key, $value] = array_pad(explode('=', trim($part), 2), 2, null);

            if ($key === 't') {
                $timestamp = $value;
            } elseif ($key === 'v1' && $value !== null && $value !== '') {
                $signatures[] = $value;
            }
        }

        if (!$timestamp || !ctype_digit((string) $timestamp) || $signatures === [] || abs(time() - (int) $timestamp) > 300) {
            return false;
        }

        $expected = hash_hmac('sha256', $timestamp . $body, $secret);

        foreach ($signatures as $signature) {
            if (hash_equals($expected, $signature)) {
                return true;
            }
        }

        return false;
    }
}
