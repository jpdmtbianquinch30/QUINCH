<?php

namespace App\Services\PaymentGateway;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;

/**
 * NOTE IMPORTANTE : Orange Money Sénégal n'a pas d'API self-service comme
 * Wave. L'accès nécessite un compte marchand validé par Sonatel (RCCM,
 * NINEA, RIB, CNI). Cette classe suit le pattern standard "Orange Money
 * WebPayment" (OAuth2 client_credentials puis POST /v1/webpayment) utilisé
 * dans les pays où Orange documente l'API publiquement. Les noms de champs
 * exacts (order_id, pay_token, statut...) sont à confirmer avec la
 * documentation que Sonatel vous remettra à l'activation — ajustez cette
 * classe en conséquence à ce moment-là, l'interface ne changera pas.
 */
class OrangeMoneyGateway implements PaymentGatewayInterface
{
    public function initiatePayment(array $request): array
    {
        $config = config('services.orange_money');

        if (!$config['client_id'] || !$config['client_secret'] || !$config['merchant_key']) {
            Log::error('Orange Money: identifiants manquants (client_id/secret/merchant_key).');
            return ['success' => false, 'message' => "Orange Money n'est pas configuré."];
        }

        $token = $this->getAccessToken($config);
        if (!$token) {
            return ['success' => false, 'message' => "Impossible de s'authentifier auprès d'Orange Money."];
        }

        $response = Http::withToken($token)->timeout(10)->post("{$config['base_url']}/webpayment", [
            'merchant_key' => $config['merchant_key'],
            'currency' => 'XOF',
            'order_id' => $request['transaction_id'],
            'amount' => (int) round($request['amount']),
            'return_url' => $request['success_url'],
            'cancel_url' => $request['error_url'],
            'notif_url' => $request['notif_url'],
            'lang' => 'fr',
            'reference' => 'QUINCH-' . $request['transaction_id'],
        ]);

        if ($response->failed()) {
            Log::error('Orange Money: échec création paiement', [
                'status' => $response->status(),
                'body' => $response->body(),
            ]);
            return ['success' => false, 'message' => 'Impossible de contacter Orange Money pour le moment.'];
        }

        $data = $response->json();

        return [
            'success' => true,
            'payment_url' => $data['payment_url'] ?? null,
            'gateway_reference' => $data['pay_token'] ?? $data['order_id'] ?? null,
            'gateway' => 'orange_money',
        ];
    }

    private function getAccessToken(array $config): ?string
    {
        return Cache::remember('orange_money_access_token', 590, function () use ($config) {
            $response = Http::asForm()
                ->withBasicAuth($config['client_id'], $config['client_secret'])
                ->post($config['auth_url'], ['grant_type' => 'client_credentials']);

            if ($response->failed()) {
                Log::error('Orange Money: échec authentification OAuth2', ['body' => $response->body()]);
                return null;
            }

            return $response->json('access_token');
        });
    }

    public function verifyPayment(string $gatewayReference): array
    {
        $config = config('services.orange_money');
        $token = $this->getAccessToken($config);

        $response = Http::withToken($token)->get("{$config['base_url']}/transactionstatus", [
            'order_id' => $gatewayReference,
            'pay_token' => $gatewayReference,
        ]);

        if ($response->failed()) {
            return ['verified' => false, 'status' => 'unknown'];
        }

        $status = $response->json('status') ?? 'unknown';

        return ['verified' => $status === 'SUCCESS', 'status' => $status];
    }

    public function refundPayment(string $gatewayReference, float $amount): array
    {
        return ['success' => false, 'message' => 'Remboursement Orange Money à traiter manuellement avec Sonatel.'];
    }

    public function getName(): string { return 'Orange Money'; }
    public function getFeeRate(): float { return 0.025; }
}