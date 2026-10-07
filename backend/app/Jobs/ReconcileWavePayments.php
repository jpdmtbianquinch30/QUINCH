<?php

namespace App\Jobs;

use App\Models\PremiumSubscription;
use App\Models\Product;
use App\Services\PaymentGateway\WaveGateway;
use App\Services\Payments\WavePaymentConfirmer;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Support\Facades\Log;

/**
 * Rattrapage des paiements Wave dont le webhook n'est jamais arrivé (panne,
 * erreur 5xx de notre côté, URL mal enregistrée...). Wave réessaie ses
 * webhooks pendant 3 jours mais ne garantit ni l'ordre ni la livraison : on
 * interroge donc Wave directement pour tout paiement « en attente » de plus de
 * 3 minutes.
 *
 *  - session payée       -> confirmation (même code que le webhook, idempotent)
 *  - toutes expirées     -> abonnement annulé / frais marqués « failed »
 *  - encore ouverte ou Wave injoignable -> on ne touche à rien, prochain passage
 */
class ReconcileWavePayments implements ShouldQueue
{
    use Dispatchable, Queueable;

    public int $timeout = 240;

    private const BATCH = 40;

    public function handle(WavePaymentConfirmer $confirmer): void
    {
        if (blank(config('services.wave.api_key'))) {
            return;
        }

        $gateway = new WaveGateway();
        $deadline = now()->addSeconds(150);
        $stats = ['confirmed' => 0, 'expired' => 0, 'checked' => 0];

        $subscriptions = PremiumSubscription::where('status', 'pending')
            ->where('payment_method', 'wave')
            ->whereNotNull('payment_gateway_id')
            ->where('created_at', '<', now()->subMinutes(3))
            ->where('created_at', '>', now()->subDays(3))
            ->orderBy('created_at')
            ->limit(self::BATCH)
            ->get();

        foreach ($subscriptions as $subscription) {
            if (now()->greaterThan($deadline)) {
                break;
            }

            $stats['checked']++;
            $verdict = $this->verdict($gateway, 'premium_' . $subscription->id, (string) $subscription->payment_gateway_id);

            if ($verdict['status'] === 'paid') {
                $result = $confirmer->confirmPremium($subscription->id, $verdict['session']);
                $stats['confirmed'] += $result === WavePaymentConfirmer::ACTIVATED ? 1 : 0;
            } elseif ($verdict['status'] === 'expired') {
                $confirmer->expirePremium($subscription->id);
                $stats['expired']++;
            }
        }

        $products = Product::where('status', 'draft')
            ->whereIn('listing_fee_status', ['pending', 'failed'])
            ->whereNotNull('listing_fee_gateway_id')
            ->where('updated_at', '<', now()->subMinutes(3))
            ->where('updated_at', '>', now()->subDays(3))
            ->orderBy('updated_at')
            ->limit(self::BATCH)
            ->get();

        foreach ($products as $product) {
            if (now()->greaterThan($deadline)) {
                break;
            }

            $stats['checked']++;
            $verdict = $this->verdict($gateway, 'listing_' . $product->id, (string) $product->listing_fee_gateway_id);

            if ($verdict['status'] === 'paid') {
                $result = $confirmer->confirmListingFee($product->id, $verdict['session']);
                $stats['confirmed'] += $result === WavePaymentConfirmer::ACTIVATED ? 1 : 0;
            } elseif ($verdict['status'] === 'expired') {
                $confirmer->failListingFee($product->id);
                $stats['expired']++;
            }
        }

        if ($stats['confirmed'] > 0 || $stats['expired'] > 0) {
            Log::info('Rattrapage Wave', $stats);
        }
    }

    /**
     * @return array{status: 'paid'|'expired'|'open'|'unknown', session: array}
     */
    private function verdict(WaveGateway $gateway, string $clientReference, string $storedSessionId): array
    {
        // 1) Toutes les sessions de cette référence (un paiement relancé en crée une nouvelle).
        $sessions = $gateway->searchSessions($clientReference);

        // 2) Repli : la session dont on a gardé l'identifiant.
        if ($sessions === null) {
            $single = $gateway->retrieveSession($storedSessionId);
            $sessions = $single === null ? null : [$single];
        }

        if ($sessions === null || $sessions === []) {
            return ['status' => 'unknown', 'session' => []];
        }

        foreach ($sessions as $session) {
            $belongs = !isset($session['client_reference']) || $session['client_reference'] === $clientReference;

            if ($belongs && ($session['payment_status'] ?? null) === 'succeeded') {
                return ['status' => 'paid', 'session' => $session];
            }
        }

        $allExpired = collect($sessions)->every(fn ($s) => ($s['checkout_status'] ?? null) === 'expired');

        return ['status' => $allExpired ? 'expired' : 'open', 'session' => []];
    }
}
