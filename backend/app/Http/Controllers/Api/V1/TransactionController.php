<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\Transaction;
use App\Services\ConversationTaggingService;
use Illuminate\Database\QueryException;
use App\Services\PaymentGateway\PaymentGatewayFactory;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\Rule;
use Illuminate\Support\Facades\DB;
use App\Support\VerifiesWaveWebhook;
use App\Models\UserReport;
use App\Support\ResolvesFrontendUrl;
use App\Models\Conversation;
use App\Models\Message;
use App\Services\Payments\OrderPaymentConfirmer;


class TransactionController extends Controller
{
    use ResolvesFrontendUrl;
    use VerifiesWaveWebhook;

    public function __construct(private \App\Services\NotificationService $notif) {}

    public function initiate(Request $request): JsonResponse
    {
        $enabledMethods = config('quinch.enabled_payment_methods', ['wave']);

        $validated = $request->validate([
            'product_id' => ['required', 'uuid', 'exists:products,id'],
            'payment_method' => ['required', Rule::in($enabledMethods)],
            'delivery_type' => ['required', 'in:pickup,delivery,meetup'],
            'delivery_address' => ['required_if:delivery_type,delivery', 'array'],
            'quantity' => ['sometimes', 'integer', 'min:1'],
        ], [
            'payment_method.in' => 'Ce moyen de paiement n\'est pas encore disponible.',
        ]);

        $qty = $validated['quantity'] ?? 1;

        // Verrou + décrément atomique du stock (règle la race condition + le multi-unités)
        $product = DB::transaction(function () use ($validated, $request, $qty) {
            $product = Product::where('id', $validated['product_id'])->lockForUpdate()->firstOrFail();

            if ($product->user_id === $request->user()->id) {
                abort(422, 'Vous ne pouvez pas acheter votre propre produit.');
            }

            if ($product->status !== 'active' || $product->stock_quantity < $qty) {
                abort(422, 'Ce produit n\'est plus disponible en quantité suffisante.');
            }

            $product->decrement('stock_quantity', $qty);
            if ($product->stock_quantity <= 0) {
                $product->update(['status' => 'reserved']);
            }

            return $product;
        });

        try {
            $gateway = PaymentGatewayFactory::create($validated['payment_method']);
        } catch (\InvalidArgumentException $e) {
            // Garde-fou : évite un 500 si QUINCH_PAYMENT_METHODS autorise une
            // méthode que PaymentGatewayFactory ne sait pas encore gérer.
            $this->releaseStock($product, $qty);
            Log::error('Transaction: passerelle de paiement non supportée', [
                'payment_method' => $validated['payment_method'],
            ]);
            return response()->json([
                'message' => 'Ce moyen de paiement n\'est pas disponible pour le moment.',
            ], 422);
        }

        $fee = round($product->price * $qty * $gateway->getFeeRate(), 2);

        $transaction = Transaction::create([
            'buyer_id' => $request->user()->id,
            'seller_id' => $product->user_id,
            'product_id' => $product->id,
            'quantity' => $qty,
            'amount' => $product->price * $qty,
            'currency' => 'XOF',
            'payment_method' => $validated['payment_method'],
            'payment_status' => 'pending',
            'order_status' => 'pending_payment',
            'security_check' => 'pending',
            'delivery_type' => $validated['delivery_type'],
            'delivery_address' => $validated['delivery_address'] ?? null,
            'transaction_fee' => $fee,
        ]);

         $this->notif->notifyTransaction(
        $product->user_id, 'initiated', $transaction->id, $product->title, $transaction->amount
        );

        $this->tagProductInConversation($transaction, $product);
        $frontendUrl = $this->resolveFrontendUrl($request);

        $result = $gateway->initiatePayment([
            'amount' => $product->price * $qty + $fee,
            'transaction_id' => $transaction->id,
            'success_url' => "{$frontendUrl}/transactions/{$transaction->id}/success",
            'error_url' => "{$frontendUrl}/transactions/{$transaction->id}/error",
            'notif_url' => url('/api/v1/webhooks/' . $this->webhookSlug($validated['payment_method'])),
        ]);

        if (!($result['success'] ?? false)) {
            $this->releaseStock($product, $qty);
            $transaction->markPaymentFailed();
            return response()->json([
                'message' => $result['message'] ?? 'Le paiement n\'a pas pu être initié.',
            ], 502);
        }

        $transaction->update(['payment_gateway_id' => $result['gateway_reference'] ?? null]);

        return response()->json([
            'message' => 'Redirection vers le paiement.',
            'transaction' => $transaction->fresh()->load(['product', 'seller']),
            'payment_url' => $result['payment_url'],
            'total_amount' => $product->price * $qty + $fee,
            'fee' => $fee,
        ], 201);
    }

        /**
     * Notifie l'autre partie à la transaction d'un changement de statut,
     * et lui envoie en plus le motif (annulation, etc.) comme message
     * si l'auteur de l'action en a laissé un.
     */
    private function notifyOtherParty(Transaction $transaction, string $status, ?string $note = null): void
    {
        $actingUserId = request()->user()->id;
        $recipientId = $transaction->buyer_id === $actingUserId ? $transaction->seller_id : $transaction->buyer_id;

        $this->notif->notifyTransaction($recipientId, $status, $transaction->id, $transaction->product->title, $transaction->amount);

        if ($note) {
            $role = $actingUserId === $transaction->seller_id ? 'vendeur' : 'acheteur';
            $this->notif->send($recipientId, 'transaction', "Message du {$role}", $note, [
                'icon' => 'info',
                'action_url' => '/messages',
                'priority' => \App\Services\NotificationService::PRIORITY_NORMAL,
                'data' => ['transaction_id' => $transaction->id],
            ]);
        }
    }

    /**
     * Annule un paiement en cours et restitue le stock au produit.
     */
    public function cancelPayment(Request $request, Transaction $transaction): JsonResponse
    {
        if ($transaction->buyer_id !== $request->user()->id) abort(403);

        if ($transaction->order_status !== 'pending_payment') {
            return response()->json(['message' => 'Cette transaction ne peut plus être annulée.'], 422);
        }

        $transaction->update(['order_status' => 'cancelled', 'payment_status' => 'failed']);
        $this->releaseStock($transaction->product, $transaction->quantity ?? 1);

        return response()->json(['message' => 'Paiement annulé, stock restitué.']);
    }

    /** Passage d'état atomique : ne réussit que si la commande est encore dans l'un des états attendus. */
    private function transition(Transaction $transaction, array $from, array $to): bool
    {
        return Transaction::whereKey($transaction->id)->whereIn('order_status', $from)->update($to) === 1;
    }

    private function releaseStock(Product $product, int $qty): void
    {
        DB::transaction(function () use ($product, $qty) {
            $locked = Product::where('id', $product->id)->lockForUpdate()->first();
            if (!$locked) return;
            $locked->increment('stock_quantity', $qty);
            if ($locked->status === 'reserved' && $locked->stock_quantity > 0) {
                $locked->update(['status' => 'active']);
            }
        });
    }

    public function history(Request $request): JsonResponse
    {
        $user = $request->user();

        $purchases = $user->purchasedTransactions()
            ->with(['product:id,title,slug,price,currency', 'seller:id,username,full_name,avatar_url'])
            ->latest()->paginate(50, ['*'], 'purchases_page');

        $sales = $user->soldTransactions()
            ->with(['product:id,title,slug,price,currency', 'buyer:id,username,full_name,avatar_url'])
            ->latest()->paginate(50, ['*'], 'sales_page');

        $allPurchases = $user->purchasedTransactions()->get();
        $allSales = $user->soldTransactions()->get();

        $stats = [
            'total_spent' => $allPurchases->where('payment_status', 'completed')->sum('amount'),
            'total_earned' => $allSales->where('payment_status', 'completed')->sum('amount'),
            'total_fees' => $allSales->where('payment_status', 'completed')->sum('transaction_fee'),
            'purchases_count' => $allPurchases->count(),
            'sales_count' => $allSales->count(),
            'completed_purchases' => $allPurchases->where('order_status', 'completed')->count(),
            'completed_sales' => $allSales->where('order_status', 'completed')->count(),
            'pending_purchases' => $allPurchases->whereIn('order_status', ['pending_payment', 'processing', 'shipped'])->count(),
            'pending_sales' => $allSales->whereIn('order_status', ['pending_payment', 'processing', 'shipped'])->count(),
            'cancelled_count' => $allPurchases->where('order_status', 'cancelled')->count()
                + $allSales->where('order_status', 'cancelled')->count(),
        ];

        return response()->json(['purchases' => $purchases, 'sales' => $sales, 'stats' => $stats]);
    }

    public function show(Request $request, Transaction $transaction): JsonResponse
    {
        $user = $request->user();

        if ($transaction->buyer_id !== $user->id && $transaction->seller_id !== $user->id && !$user->isAdmin()) {
            return response()->json(['message' => 'Non autorisé.'], 403);
        }

        return response()->json([
            'transaction' => $transaction->load(['product', 'seller:id,username,full_name,avatar_url,phone_number', 'buyer:id,username,full_name,avatar_url,phone_number']),
        ]);
    }

    public function updateStatus(Request $request, Transaction $transaction): JsonResponse
    {
        $user = $request->user();
        $validated = $request->validate([
            'status' => ['required', 'in:processing,shipped,delivered,completed,cancelled'],
            'note' => ['sometimes', 'string', 'max:500'],
        ]);
        $newStatus = $validated['status'];

        // Paiement cash : payment_status reste volontairement 'pending' (voir
        // CashGateway) puisqu'aucune passerelle externe ne le confirme jamais
        // — l'échange se fait physiquement. Sans cette exception, ce garde
        // bloquait à tort TOUTE progression (expédié, livré, réception
        // confirmée) des commandes payées en espèces.
        $isCashAwaitingHandoff = $transaction->payment_method === 'cash' && $transaction->payment_status === 'pending';

        if (!$isCashAwaitingHandoff && $transaction->payment_status !== 'completed' && $newStatus !== 'cancelled') {
            return response()->json(['message' => "Le paiement n'a pas encore été confirmé par la passerelle."], 422);
        }

        if ($transaction->seller_id === $user->id) {
            $allowed = ['processing', 'shipped', 'delivered', 'cancelled'];
            if (!in_array($newStatus, $allowed)) {
                return response()->json(['message' => 'Action non autorisée pour le vendeur.'], 422);
            }

            if ($newStatus === 'shipped' && $transaction->order_status !== 'processing') {
                return response()->json(['message' => 'La commande doit être acceptée avant expédition.'], 422);
            }

            if ($newStatus === 'delivered') {
                // Transition atomique : une commande déjà livrée, en litige ou annulée ne peut
                // plus être « livrée » (sinon le score de confiance serait gonflable à l'infini).
                if (!$this->transition($transaction, ['processing', 'shipped'], ['order_status' => 'delivered'])) {
                    return response()->json(['message' => 'Cette commande ne peut pas être marquée comme livrée dans son état actuel.'], 422);
                }
                $transaction->product->update(['status' => 'sold']);
                $user->incrementTrustScore(0.02);
                $this->notifyOtherParty($transaction, 'delivered');
                return response()->json([
                    'message' => 'Commande marquée comme livrée.',
                    'transaction' => $transaction->fresh()->load(['product', 'buyer:id,username,full_name,avatar_url']),
                ]);
            }

             if ($newStatus === 'cancelled') {
                $wasPaid = $transaction->payment_status === 'completed';
                if (!$this->transition($transaction, ['pending_payment', 'processing'], ['order_status' => 'cancelled'])) {
                    return response()->json(['message' => 'Cette commande ne peut plus être annulée.'], 422);
                }
                // Le stock réservé à l'initiation est restitué (avant : seul le statut repassait « actif »).
                $this->releaseStock($transaction->product, $transaction->quantity ?? 1);
                if ($wasPaid) {
                    // Déjà encaissée : remboursement manuel à traiter par l'équipe.
                    $transaction->update(['security_check' => 'manual_review']);
                    Log::warning('Commande payée annulée par le vendeur — REMBOURSEMENT À FAIRE', ['transaction_id' => $transaction->id]);
                }
                $this->notifyOtherParty($transaction, 'cancelled', $validated['note'] ?? null);
                return response()->json([
                    'message' => 'Commande annulée.',
                    'transaction' => $transaction->fresh()->load(['product', 'buyer:id,username,full_name,avatar_url']),
                ]);
            }

            $transaction->update(['order_status' => $newStatus]);
            $this->notifyOtherParty($transaction, $newStatus);
            return response()->json([
                'message' => 'Statut mis à jour.',
                'transaction' => $transaction->fresh()->load(['product', 'buyer:id,username,full_name,avatar_url']),
            ]);
        }

        if ($transaction->buyer_id === $user->id) {
            if ($newStatus === 'completed' && $transaction->order_status === 'delivered') {
                $transaction->update([
                    'order_status' => 'completed',
                    'completed_at' => now(),
                    'payment_status' => $transaction->payment_method === 'cash' ? 'completed' : $transaction->payment_status,
                ]);
                $transaction->seller->incrementTrustScore(0.02);
                $this->notifyOtherParty($transaction, 'completed');
                return response()->json([
                    'message' => 'Réception confirmée. Merci !',
                    'transaction' => $transaction->fresh()->load(['product', 'seller:id,username,full_name,avatar_url']),
                ]);
            }

            if ($newStatus === 'cancelled' && $transaction->order_status === 'pending_payment') {
                // Atomique ET jamais après un paiement : un webhook peut arriver pile entre la lecture et l'écriture.
                $cancelled = Transaction::whereKey($transaction->id)
                    ->where('order_status', 'pending_payment')
                    ->where('payment_status', '!=', 'completed')
                    ->update(['order_status' => 'cancelled', 'payment_status' => 'failed']);
                if ($cancelled !== 1) {
                    return response()->json(['message' => 'Cette commande ne peut plus être annulée.'], 422);
                }
                $this->releaseStock($transaction->product, $transaction->quantity ?? 1);
                $this->notifyOtherParty($transaction, 'cancelled', $validated['note'] ?? null);
                return response()->json([
                    'message' => 'Commande annulée.',
                    'transaction' => $transaction->fresh()->load(['product', 'seller:id,username,full_name,avatar_url']),
                ]);
            }
        }

        return response()->json(['message' => 'Cette action n\'est pas possible pour le statut actuel.'], 422);
    }

        public function dispute(Request $request, Transaction $transaction): JsonResponse
    {
        $validated = $request->validate([
            'reason' => ['required', 'string', 'max:1000'],
        ]);

        $user = $request->user();
        // Acheteur ET vendeur peuvent signaler un problème sur leur propre
        // transaction (avant ce fix, seul l'acheteur le pouvait alors que
        // le vendeur peut tout autant vouloir signaler un acheteur
        // problématique - fraude, harcèlement, faux prétextes, etc.).
        $isBuyer = $transaction->buyer_id === $user->id;
        $isSeller = $transaction->seller_id === $user->id;
        if (!$isBuyer && !$isSeller) {
            return response()->json(['message' => 'Non autorisé.'], 403);
        }

        $transaction->update(['security_check' => 'manual_review', 'order_status' => 'disputed']);

        // Signale l'AUTRE partie à la transaction (UserReport, même
        // mécanisme que le signalement de profil ailleurs dans l'app), en
        // gardant le contexte de la transaction dans la description pour
        // que la modération sache de quelle commande il s'agit.
        UserReport::create([
            'reporter_id' => $user->id,
            'reported_user_id' => $isBuyer ? $transaction->seller_id : $transaction->buyer_id,
            'reason' => 'other',
            'description' => "[Transaction {$transaction->id}] " . $validated['reason'],
            'status' => 'pending',
        ]);

        return response()->json(['message' => 'Signalement envoyé. Notre équipe va examiner votre cas.']);
    }

    public function webhookWave(Request $request): JsonResponse
    {
        $secret = $this->waveWebhookSecret();
        $header = $request->header('Wave-Signature');

        if (!$secret || !$header || !$this->verifyWaveSignature($header, $request->getContent(), $secret)) {
            Log::warning('Webhook Wave: signature invalide', ['ip' => $request->ip()]);
            return response()->json(['error' => 'Signature invalide'], 401);
        }

        $payload = $request->json()->all();
        $data = $payload['data'] ?? [];

        $confirmer = app(OrderPaymentConfirmer::class);
        $reference = $data['client_reference'] ?? null;

        if (($payload['type'] ?? null) === 'checkout.session.completed' && ($data['payment_status'] ?? null) === 'succeeded') {
            $confirmer->confirm(is_string($reference) ? $reference : null, [
                'id' => $data['id'] ?? null,
                'amount' => $data['amount'] ?? null,
                'currency' => $data['currency'] ?? null,
            ]);
        }

        // Échec Wave : NON final (le client peut réessayer pendant 30 min et
        // payer ensuite). On ne fait que compter ; une session abandonnée est
        // annulée par ReleaseExpiredReservations. Un échec n'annule jamais une
        // commande payée.
        if (($payload['type'] ?? null) === 'checkout.session.payment_failed') {
            $confirmer->recordFailure(is_string($reference) ? $reference : null, false);
        }

        return response()->json(['status' => 'received']);
    }

    public function webhookOrangeMoney(Request $request): JsonResponse
    {
        $signature = $request->header('X-Orange-Signature');
        $secret = config('services.orange_money.webhook_secret');

        // Schéma de signature à confirmer avec la doc Sonatel définitive.
        if (!$secret || !$signature || !hash_equals(hash_hmac('sha256', $request->getContent(), $secret), $signature)) {
            Log::warning('Webhook Orange Money: signature invalide', ['ip' => $request->ip()]);
            return response()->json(['error' => 'Signature invalide'], 401);
        }

        // Noms de champs à ajuster une fois la doc Sonatel reçue.
        $transactionRef = $request->input('order_id');
        $status = $request->input('status');
        $confirmer = app(OrderPaymentConfirmer::class);

        if ($status === 'SUCCESS') {
            $confirmer->confirm(is_string($transactionRef) ? $transactionRef : null, [
                'id' => $request->input('txnid'),
                'amount' => $request->input('amount'),
                'currency' => $request->input('currency'),
            ]);
        } elseif ($status === 'FAILED') {
            // Échec définitif : annulation + restitution du stock, une seule fois.
            $confirmer->recordFailure(is_string($transactionRef) ? $transactionRef : null, true);
        }

        return response()->json(['status' => 'received']);
    }

    private function webhookSlug(string $method): string
    {
        return match ($method) {
            'wave' => 'wave',
            'orange_money' => 'orange-money',
            default => $method,
        };
    }

    /**
 * Si une conversation existe deja entre l'acheteur et le vendeur (sinon
 * en cree une), tague automatiquement le produit commande dans la
 * discussion via un message de type product_tag.
 */
private function tagProductInConversation(Transaction $transaction, Product $product): void
{
    $find = fn () => Conversation::where(function ($q) use ($transaction) {
            $q->where('buyer_id', $transaction->buyer_id)->where('seller_id', $transaction->seller_id);
        })
        ->orWhere(function ($q) use ($transaction) {
            $q->where('buyer_id', $transaction->seller_id)->where('seller_id', $transaction->buyer_id);
        })
        ->first();

    $conversation = $find();

    if (!$conversation) {
        try {
            $conversation = Conversation::create([
                'buyer_id' => $transaction->buyer_id,
                'seller_id' => $transaction->seller_id,
                'product_id' => $product->id,
                'status' => 'active',
                'last_message_at' => now(),
            ]);
        } catch (QueryException $e) {
            if (($e->errorInfo[0] ?? null) !== '23505') {
                throw $e;
            }
            $conversation = $find();
        }
    }

    app(ConversationTaggingService::class)->tagProduct($conversation, $product, $transaction->buyer_id, $transaction);
}
}
