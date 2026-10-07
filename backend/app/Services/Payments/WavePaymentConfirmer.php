<?php

namespace App\Services\Payments;

use App\Models\PremiumSubscription;
use App\Models\Product;
use App\Services\NotificationService;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/**
 * Applique le résultat d'un paiement Wave (abonnement Premium, frais de
 * publication). Utilisé à la fois par les webhooks ET par la tâche de
 * rattrapage (ReconcileWavePayments) : un webhook perdu ne laisse donc jamais
 * un client payé sans service.
 *
 * Toutes les méthodes sont idempotentes (verrou de ligne + contrôle d'état).
 * $session = données Wave : id, amount, client_reference...
 */
class WavePaymentConfirmer
{
    public const ACTIVATED = 'activated';
    public const ALREADY = 'already';
    public const UNDERPAID = 'underpaid';
    public const IGNORED = 'ignored';

    /**
     * Un paiement réussi fait foi : un abonnement « pending » OU « cancelled »
     * (échec précédent, ou session déclarée expirée trop tôt) est activé.
     */
    public function confirmPremium(string $subscriptionId, array $session): string
    {
        return DB::transaction(function () use ($subscriptionId, $session) {
            // Verrou : deux confirmations simultanées ne doublent plus l'abonnement.
            $subscription = PremiumSubscription::whereKey($subscriptionId)->lockForUpdate()->first();

            if (!$subscription) {
                Log::warning('Wave premium: paiement reçu pour un abonnement introuvable — remboursement à étudier', [
                    'subscription_id' => $subscriptionId,
                ]);

                return self::IGNORED;
            }

            if ($subscription->status === 'active') {
                return self::ALREADY;
            }

            if (!in_array($subscription->status, ['pending', 'cancelled'], true)) {
                return self::IGNORED;
            }

            if ($this->isUnderpaid($session, (int) $subscription->amount)) {
                Log::critical('Wave premium: montant payé inférieur au prix attendu', [
                    'subscription_id' => $subscription->id,
                    'expected' => $subscription->amount,
                    'received' => $session['amount'] ?? null,
                ]);

                return self::UNDERPAID;
            }

            $subscription->update(['payment_gateway_id' => $session['id'] ?? $subscription->payment_gateway_id]);
            $subscription->activate();

            return self::ACTIVATED;
        });
    }

    /** Session expirée sans paiement : l'abonnement en attente est annulé. */
    public function expirePremium(string $subscriptionId): void
    {
        PremiumSubscription::where('id', $subscriptionId)->where('status', 'pending')->update(['status' => 'cancelled']);
    }

    public function confirmListingFee(string $productId, array $session): string
    {
        return DB::transaction(function () use ($productId, $session) {
            // Verrou : deux confirmations simultanées ne traitent pas la même annonce.
            $product = Product::whereKey($productId)->lockForUpdate()->first();

            if (!$product) {
                Log::warning('Wave listing: paiement reçu pour une annonce introuvable (supprimée ?) — remboursement à étudier', [
                    'product_id' => $productId,
                ]);

                return self::IGNORED;
            }

            if ($product->listing_fee_status === 'paid') {
                return self::ALREADY; // déjà traité (idempotent)
            }

            if (!in_array($product->listing_fee_status, ['pending', 'failed'], true)) {
                Log::warning('Wave listing: paiement reçu pour une annonce sans frais en attente — remboursement à étudier', [
                    'product_id' => $product->id,
                ]);

                return self::IGNORED;
            }

            // Le montant payé ne doit pas être inférieur aux frais attendus.
            $expected = (int) ($product->listing_fee_amount ?: config('quinch.premium.listing_fee_with_video', 150));
            if ($this->isUnderpaid($session, $expected)) {
                Log::critical('Wave listing: montant payé inférieur aux frais attendus', [
                    'product_id' => $product->id,
                    'expected' => $expected,
                    'received' => $session['amount'] ?? null,
                ]);

                return self::UNDERPAID;
            }

            // Un paiement réussi fait foi, même si une tentative précédente était « failed ».
            $product->update([
                'status' => 'active',
                'listing_fee_status' => 'paid',
                'listing_fee_gateway_id' => $session['id'] ?? $product->listing_fee_gateway_id,
            ]);

            try {
                if ($product->user) {
                    app(NotificationService::class)->notifyMentions($product->fresh(), $product->user);
                }
            } catch (\Throwable $e) {
                Log::warning('notifyMentions a échoué', ['error' => $e->getMessage()]);
            }

            return self::ACTIVATED;
        });
    }

    /** Échec ou expiration sans paiement : les frais passent de « pending » à « failed ». */
    public function failListingFee(string $productId): void
    {
        Product::where('id', $productId)->where('listing_fee_status', 'pending')->update(['listing_fee_status' => 'failed']);
    }

    private function isUnderpaid(array $session, int $expected): bool
    {
        return isset($session['amount']) && (int) round((float) $session['amount']) < $expected;
    }
}
