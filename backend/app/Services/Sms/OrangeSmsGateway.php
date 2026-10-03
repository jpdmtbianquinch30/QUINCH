<?php

namespace App\Services\Sms;

use Illuminate\Http\Client\Response;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;

/**
 * API SMS Orange (Orange Developer, SMS Sénégal).
 * Jeton OAuth2 (client_credentials) mis en cache, puis envoi via
 * /smsmessaging/v1/outbound/{senderAddress}/requests.
 *
 * ⚠️ Vérifiez les valeurs exactes (sender, sender_name) dans votre espace
 * Orange Developer : elles dépendent de votre contrat.
 */
class OrangeSmsGateway implements SmsGateway
{
    private const TOKEN_CACHE_KEY = 'sms:orange:token';

    public function send(string $to, string $message): void
    {
        $cfg = (array) config('services.sms.orange');

        if (empty($cfg['client_id']) || empty($cfg['client_secret']) || empty($cfg['sender'])) {
            throw new \RuntimeException('Orange SMS non configuré (ORANGE_SMS_CLIENT_ID / SECRET / SENDER).');
        }

        $response = $this->post($to, $message, $this->token($cfg), $cfg);

        // Jeton expiré ou révoqué : on le renouvelle une seule fois.
        if ($response->status() === 401) {
            Cache::forget(self::TOKEN_CACHE_KEY);
            $response = $this->post($to, $message, $this->token($cfg), $cfg);
        }

        if (!$response->successful()) {
            throw new \RuntimeException('Orange SMS API a répondu HTTP ' . $response->status());
        }
    }

    private function token(array $cfg): string
    {
        $cached = Cache::get(self::TOKEN_CACHE_KEY);
        if ($cached) {
            return $cached;
        }

        $response = Http::asForm()
            ->withBasicAuth($cfg['client_id'], $cfg['client_secret'])
            ->timeout(10)
            ->post($cfg['auth_url'], ['grant_type' => 'client_credentials']);

        $token = $response->json('access_token');

        if (!$response->successful() || !$token) {
            throw new \RuntimeException('Orange OAuth: jeton non obtenu (HTTP ' . $response->status() . ').');
        }

        $ttl = max(60, (int) $response->json('expires_in', 3600) - 120);
        Cache::put(self::TOKEN_CACHE_KEY, $token, $ttl);

        return $token;
    }

    private function post(string $to, string $message, string $token, array $cfg): Response
    {
        $senderUri = 'tel:' . $cfg['sender'];
        $url = rtrim($cfg['base_url'], '/') . '/outbound/' . rawurlencode($senderUri) . '/requests';

        $body = [
            'address'                => 'tel:' . $to,
            'senderAddress'          => $senderUri,
            'outboundSMSTextMessage' => ['message' => $message],
        ];

        if (!empty($cfg['sender_name'])) {
            $body['senderName'] = $cfg['sender_name'];
        }

        return Http::withToken($token)
            ->acceptJson()
            ->asJson()
            ->timeout(10)
            ->post($url, ['outboundSMSMessageRequest' => $body]);
    }
}
