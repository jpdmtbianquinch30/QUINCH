<?php

namespace App\Services\Payments;

use App\Models\Product;
use App\Models\Transaction;
use App\Services\NotificationService;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

/**
 * Applique le résultat d'un paiement de COMMANDE (Wave, Orange Money).
 *
 * Règles (toutes sous verrou de ligne, donc idempotentes et sans course) :
 *  - un paiement RÉUSSI fait foi et n'est jamais défait par un événement
 *    d'échec arrivé plus tard (ou rejoué) ;
 *  - un échec n'annule JAMAIS une commande déjà payée ;
 *  - Wave peut signaler plusieurs échecs avant un succès (le client réessaie
 *    pendant 30 min) : un échec « non final » ne fait que compter, la
 *    réservation expire via ReleaseExpiredReservations ;
 *  - le montant ET la devise doivent correspondre au prix attendu
 *    (commande + frais), sinon la commande reste impayée et part en revue ;
 *  - rejouer deux fois le même webhook ne change rien (stock inclus).
 */
class OrderPaymentConfirmer
{
    public const PAID = 'paid';               // paiement enregistré, commande en préparation
    public const PAID_RESTOCKED = 'paid_restocked'; // réservation expirée, stock re-réservé
    public const PAID_NO_STOCK = 'paid_no_stock';   // payé mais plus de stock : remboursement à faire
    public const ALREADY = 'already';
    public const REJECTED = 'rejected';       // montant/devise invalide
    public const IGNORED = 'ignored';

    public function __construct(private NotificationService $notif) {}

    /**
     * @param array $session ['id' => réf. passerelle, 'amount' => montant payé, 'currency' => devise]
     */
    public function confirm(?string $transactionId, array $session): string
    {
        if (!is_string($transactionId) || !Str::isUuid($transactionId)) {
            return self::IGNORED;
        }

        $transaction = null;

        $result = DB::transaction(function () use ($transactionId, $session, &$transaction) {
            $transaction = Transaction::whereKey($transactionId)->lockForUpdate()->first();

            if (!$transaction) {
                Log::warning('Paiement reçu pour une commande introuvable — remboursement à étudier', [
                    'transaction_id' => $transactionId,
                ]);

                return self::IGNORED;
            }

            if ($transaction->payment_status === 'completed') {
                return self::ALREADY;
            }

            if (!$this->amountMatches($transaction, $session)) {
                Log::critical('Paiement commande : montant ou devise inattendu — commande NON validée', [
                    'transaction_id' => $transaction->id,
                    'expected' => $this->expectedAmount($transaction),
                    'received' => $session['amount'] ?? null,
                    'currency' => $session['currency'] ?? null,
                ]);
                $transaction->update(['security_check' => 'manual_review']);

                return self::REJECTED;
            }

            $gatewayRef = isset($session['id']) ? (string) $session['id'] : null;

            if ($transaction->order_status === 'pending_payment') {
                $transaction->markPaid($gatewayRef);

                return self::PAID;
            }

            if ($transaction->order_status === 'cancelled') {
                // Réservation expirée (ou échec précédent) puis paiement réussi :
                // l'argent est encaissé, on tente de re-réserver le stock.
                $qty = $transaction->quantity ?? 1;
                $product = Product::whereKey($transaction->product_id)->lockForUpdate()->first();

                if ($product && $product->status !== 'disabled' && $product->stock_quantity >= $qty
                    && in_array($product->status, ['active', 'reserved'], true)) {
                    $product->decrement('stock_quantity', $qty);
                    if ($product->stock_quantity <= 0) {
                        $product->update(['status' => 'reserved']);
                    }
                    $transaction->markPaid($gatewayRef);

                    return self::PAID_RESTOCKED;
                }

                // Plus de stock : on garde la preuve du paiement et on bloque la
                // commande pour un remboursement manuel (jamais de survente).
                $transaction->markPaid($gatewayRef);
                $transaction->update(['order_status' => 'disputed', 'security_check' => 'manual_review']);
                Log::critical('Paiement reçu mais stock indisponible — REMBOURSEMENT À FAIRE', [
                    'transaction_id' => $transaction->id,
                ]);

                return self::PAID_NO_STOCK;
            }

            return self::IGNORED;
        });

        if (in_array($result, [self::PAID, self::PAID_RESTOCKED], true) && $transaction) {
            $this->notifyPaid($transaction);
        }

        return $result;
    }

    /**
     * Échec signalé par la passerelle.
     *
     * @param bool $final true si l'échec est définitif (Orange Money) : la
     *                    commande est alors annulée et le stock restitué UNE fois.
     *                    false pour Wave (d'autres tentatives peuvent suivre).
     */
    public function recordFailure(?string $transactionId, bool $final): string
    {
        if (!is_string($transactionId) || !Str::isUuid($transactionId)) {
            return self::IGNORED;
        }

        return DB::transaction(function () use ($transactionId, $final) {
            $transaction = Transaction::whereKey($transactionId)->lockForUpdate()->first();

            if (!$transaction) {
                return self::IGNORED;
            }

            // Un paiement réussi n'est jamais défait par un échec (tardif ou rejoué).
            if ($transaction->payment_status === 'completed') {
                return self::ALREADY;
            }

            $transaction->increment('payment_failure_count');

            if (!$final || $transaction->order_status !== 'pending_payment') {
                return self::IGNORED;
            }

            $transaction->update(['order_status' => 'cancelled', 'payment_status' => 'failed']);

            $product = Product::whereKey($transaction->product_id)->lockForUpdate()->first();
            if ($product) {
                $product->increment('stock_quantity', $transaction->quantity ?? 1);
                if ($product->status === 'reserved' && $product->stock_quantity > 0) {
                    $product->update(['status' => 'active']);
                }
            }

            return self::IGNORED;
        });
    }

    /** Montant attendu côté passerelle : prix × quantité + frais (voir TransactionController::initiate). */
    private function expectedAmount(Transaction $transaction): int
    {
        return (int) round((float) $transaction->amount + (float) $transaction->transaction_fee);
    }

    /** Le montant doit être présent ET au moins égal à l'attendu ; la devise (si fournie) doit être XOF. */
    private function amountMatches(Transaction $transaction, array $session): bool
    {
        if (!isset($session['amount']) || !is_numeric($session['amount'])) {
            return false;
        }

        if (isset($session['currency']) && strtoupper((string) $session['currency']) !== strtoupper((string) ($transaction->currency ?: 'XOF'))) {
            return false;
        }

        return (int) round((float) $session['amount']) >= $this->expectedAmount($transaction);
    }

    private function notifyPaid(Transaction $transaction): void
    {
        try {
            $title = $transaction->product?->title ?? 'Commande';
            $this->notif->notifyTransaction($transaction->buyer_id, 'confirmed', $transaction->id, $title, $transaction->amount);
            $this->notif->notifyTransaction($transaction->seller_id, 'confirmed', $transaction->id, $title, $transaction->amount);
        } catch (\Throwable $e) {
            Log::warning('Notification de paiement échouée', ['error' => $e->getMessage()]);
        }
    }
}
