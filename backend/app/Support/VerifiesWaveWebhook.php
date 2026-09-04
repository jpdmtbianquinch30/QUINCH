<?php

namespace App\Support;

trait VerifiesWaveWebhook
{
    /**
     * Le fallback "dev-simulation-secret" (config/services.php) est un
     * texte public et prévisible — jamais utilisable pour vérifier une
     * vraie signature Wave en production, sinon n'importe qui pourrait
     * forger un webhook valide. On le neutralise explicitement ici plutôt
     * que dans le fichier de config (qui peut être mis en cache et donc
     * figer un résultat obsolète — voir commentaire dans services.php).
     */
    private function waveWebhookSecret(): ?string
    {
        $secret = config('services.wave.webhook_secret');

        if (app()->environment('production') && $secret === 'dev-simulation-secret') {
            return null;
        }

        return $secret;
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