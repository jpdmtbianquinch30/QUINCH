<?php

namespace App\Services\PaymentGateway;

use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\PendingRequest;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Passerelle Wave (Checkout API). Références : https://docs.wave.com/checkout
 *
 * - Les webhooks ne se déclarent PAS par session : ils sont enregistrés dans le
 *   portail Wave Business (une URL + un secret par webhook). Il n'existe pas de
 *   paramètre « notif_url » dans l'API de création de session.
 * - Une session expire au bout de 30 minutes ; plusieurs échecs de paiement
 *   peuvent précéder un succès dans la même session.
 */
class WaveGateway implements PaymentGatewayInterface
{
    public function initiatePayment(array $request): array
    {
        $apiKey = config('services.wave.api_key');

        if (!$apiKey) {
            // Aucune clé Wave : on refuse, quel que soit l'environnement.
            // Il n'existe plus de mode simulation ; les tests utilisent Http::fake().
            Log::error('Wave: WAVE_API_KEY manquante.');
            return ['success' => false, 'message' => "Wave n'est pas configuré."];
        }

        // Le XOF n'accepte pas de décimales côté Wave.
        $payload = [
            'amount' => (string) round($request['amount']),
            'currency' => 'XOF',
            'client_reference' => $request['transaction_id'],
            'success_url' => $request['success_url'],
            'error_url' => $request['error_url'],
        ];

        try {
            $response = $this->http()->post("{$this->baseUrl()}/checkout/sessions", $payload);
        } catch (ConnectionException $e) {
            Log::error('Wave: connexion impossible (création de session)', ['error' => $this->shorten($e->getMessage())]);

            return ['success' => false, 'message' => 'Impossible de contacter Wave pour le moment.'];
        }

        if ($response->failed()) {
            Log::error('Wave: échec création session checkout', [
                'status' => $response->status(),
                'body' => $this->shorten($response->body()),
            ]);

            return ['success' => false, 'message' => 'Impossible de contacter Wave pour le moment.'];
        }

        $data = $response->json();

        if (empty($data['wave_launch_url']) || empty($data['id'])) {
            Log::error('Wave: réponse de création de session incomplète', ['body' => $this->shorten($response->body())]);

            return ['success' => false, 'message' => 'Réponse inattendue de Wave. Réessayez dans un instant.'];
        }

        return [
            'success' => true,
            'payment_url' => $data['wave_launch_url'],
            'gateway_reference' => $data['id'],
            'gateway' => 'wave',
        ];
    }

    /**
     * Lit une session Wave (source de vérité du statut). Retourne null si Wave
     * est injoignable, répond en erreur ou si la clé API est absente.
     *
     * Champs utiles : id, amount, client_reference, checkout_status
     * (open|complete|expired) et payment_status (processing|cancelled|succeeded).
     */
    public function retrieveSession(string $sessionId): ?array
    {
        if (!config('services.wave.api_key') || $sessionId === '') {
            return null;
        }

        try {
            $response = $this->http()->get("{$this->baseUrl()}/checkout/sessions/" . rawurlencode($sessionId));
        } catch (ConnectionException $e) {
            Log::warning('Wave: connexion impossible (lecture de session)', ['error' => $this->shorten($e->getMessage())]);

            return null;
        }

        if ($response->failed() || !is_array($response->json())) {
            Log::warning('Wave: lecture de session en échec', ['status' => $response->status()]);

            return null;
        }

        return $response->json();
    }

    /**
     * Toutes les sessions Wave portant un client_reference donné (un paiement
     * relancé crée une nouvelle session). Retourne null si la recherche échoue.
     *
     * @return array<int, array<string, mixed>>|null
     */
    public function searchSessions(string $clientReference): ?array
    {
        if (!config('services.wave.api_key') || $clientReference === '') {
            return null;
        }

        try {
            $response = $this->http()->get("{$this->baseUrl()}/checkout/sessions/search", [
                'client_reference' => $clientReference,
            ]);
        } catch (ConnectionException $e) {
            Log::warning('Wave: connexion impossible (recherche de sessions)', ['error' => $this->shorten($e->getMessage())]);

            return null;
        }

        if ($response->failed()) {
            return null;
        }

        $body = $response->json();
        $list = $body['result'] ?? $body['data'] ?? $body['sessions'] ?? (is_array($body) && array_is_list($body) ? $body : null);

        return is_array($list) ? array_values(array_filter($list, 'is_array')) : null;
    }

    public function verifyPayment(string $gatewayReference): array
    {
        $data = $this->retrieveSession($gatewayReference);

        if ($data === null) {
            return ['verified' => false, 'status' => 'unknown'];
        }

        return [
            'verified' => ($data['payment_status'] ?? null) === 'succeeded',
            'status' => $data['payment_status'] ?? 'unknown',
            'transaction_id' => $data['transaction_id'] ?? null,
        ];
    }

    public function refundPayment(string $gatewayReference, float $amount): array
    {
        try {
            $response = $this->http()->post("{$this->baseUrl()}/checkout/sessions/" . rawurlencode($gatewayReference) . '/refund');
        } catch (ConnectionException $e) {
            Log::error('Wave: connexion impossible (remboursement)', ['error' => $this->shorten($e->getMessage())]);

            return ['success' => false, 'message' => 'Impossible de contacter Wave pour le moment.'];
        }

        return [
            'success' => $response->successful(),
            'message' => $response->successful() ? null : $this->shorten($response->body()),
        ];
    }

    public function getName(): string { return 'Wave'; }
    public function getFeeRate(): float { return 0.01; }

    private function http(): PendingRequest
    {
        return Http::withToken((string) config('services.wave.api_key'))
            ->acceptJson()
            ->connectTimeout(5)
            ->timeout(10);
    }

    private function baseUrl(): string
    {
        return rtrim((string) config('services.wave.base_url', 'https://api.wave.com/v1'), '/');
    }

    private function shorten(string $text): string
    {
        return mb_substr($text, 0, 300);
    }
}
