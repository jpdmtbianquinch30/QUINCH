<?php

namespace App\Support;

trait VerifiesWaveWebhook
{
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