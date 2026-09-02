<?php

namespace App\Services\PaymentGateway;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class WaveGateway implements PaymentGatewayInterface
{
    public function initiatePayment(array $request): array
    {
        $apiKey = config('services.wave.api_key');
        $baseUrl = config('services.wave.base_url', 'https://api.wave.com/v1');

        if (!$apiKey) {
            Log::error('Wave: WAVE_API_KEY manquante.');
            return ['success' => false, 'message' => "Wave n'est pas configuré."];
        }

        // Le XOF n'accepte pas de décimales côté Wave.
        $amount = (string) round($request['amount']);

        $payload = [
            'amount' => $amount,
            'currency' => 'XOF',
            'client_reference' => $request['transaction_id'],
            'success_url' => $request['success_url'],
            'error_url' => $request['error_url'],
        ];

        // notif_url est optionnel : utilisé pour les flux qui doivent être
        // notifiés sur un webhook différent de celui par défaut du compte
        // marchand (ex. abonnements premium -> /webhooks/wave-premium).
        // Sans ce champ, Wave enverrait la confirmation de paiement sur
        // l'URL webhook par défaut du dashboard, jamais sur wave-premium.
        if (!empty($request['notif_url'])) {
            $payload['notif_url'] = $request['notif_url'];
        }

        $response = Http::withToken($apiKey)->timeout(10)->post("{$baseUrl}/checkout/sessions", $payload);

        if ($response->failed()) {
            Log::error('Wave: échec création session checkout', [
                'status' => $response->status(),
                'body' => $response->body(),
            ]);
            return ['success' => false, 'message' => 'Impossible de contacter Wave pour le moment.'];
        }

        $data = $response->json();

        return [
            'success' => true,
            'payment_url' => $data['wave_launch_url'] ?? null,
            'gateway_reference' => $data['id'] ?? null,
            'gateway' => 'wave',
        ];
    }

    public function verifyPayment(string $gatewayReference): array
    {
        $apiKey = config('services.wave.api_key');
        $baseUrl = config('services.wave.base_url', 'https://api.wave.com/v1');

        $response = Http::withToken($apiKey)->get("{$baseUrl}/checkout/sessions/{$gatewayReference}");

        if ($response->failed()) {
            return ['verified' => false, 'status' => 'unknown'];
        }

        $data = $response->json();

        return [
            'verified' => ($data['payment_status'] ?? null) === 'succeeded',
            'status' => $data['payment_status'] ?? 'unknown',
            'transaction_id' => $data['transaction_id'] ?? null,
        ];
    }

    public function refundPayment(string $gatewayReference, float $amount): array
    {
        $apiKey = config('services.wave.api_key');
        $baseUrl = config('services.wave.base_url', 'https://api.wave.com/v1');

        $response = Http::withToken($apiKey)->post("{$baseUrl}/checkout/sessions/{$gatewayReference}/refund");

        return [
            'success' => $response->successful(),
            'message' => $response->successful() ? null : $response->body(),
        ];
    }

    public function getName(): string { return 'Wave'; }
    public function getFeeRate(): float { return 0.01; }
}