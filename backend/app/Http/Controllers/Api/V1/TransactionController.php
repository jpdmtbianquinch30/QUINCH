<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\Transaction;
use App\Services\PaymentGateway\PaymentGatewayFactory;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\Rule;

class TransactionController extends Controller
{
    public function initiate(Request $request): JsonResponse
    {
        $enabledMethods = config('quinch.enabled_payment_methods', ['wave']);

        $validated = $request->validate([
            'product_id' => ['required', 'uuid', 'exists:products,id'],
            'payment_method' => ['required', Rule::in($enabledMethods)],
            'delivery_type' => ['required', 'in:pickup,delivery,meetup'],
            'delivery_address' => ['required_if:delivery_type,delivery', 'array'],
        ], [
            'payment_method.in' => 'Ce moyen de paiement n\'est pas encore disponible.',
        ]);

        $product = Product::findOrFail($validated['product_id']);

        if ($product->user_id === $request->user()->id) {
            return response()->json(['message' => 'Vous ne pouvez pas acheter votre propre produit.'], 422);
        }

        if ($product->status !== 'active') {
            return response()->json(['message' => 'Ce produit n\'est plus disponible.'], 422);
        }

        $gateway = PaymentGatewayFactory::create($validated['payment_method']);
        $fee = round($product->price * $gateway->getFeeRate(), 2);

        $transaction = Transaction::create([
            'buyer_id' => $request->user()->id,
            'seller_id' => $product->user_id,
            'product_id' => $product->id,
            'amount' => $product->price,
            'currency' => 'XOF',
            'payment_method' => $validated['payment_method'],
            'payment_status' => 'pending',
            'order_status' => 'pending_payment',
            'security_check' => 'pending',
            'delivery_type' => $validated['delivery_type'],
            'delivery_address' => $validated['delivery_address'] ?? null,
            'transaction_fee' => $fee,
        ]);

        $frontendUrl = rtrim(config('quinch.frontend_url'), '/');

        $result = $gateway->initiatePayment([
            'amount' => $product->price + $fee,
            'transaction_id' => $transaction->id,
            'success_url' => "{$frontendUrl}/transactions/{$transaction->id}/success",
            'error_url' => "{$frontendUrl}/transactions/{$transaction->id}/error",
            'notif_url' => url('/api/v1/webhooks/' . $this->webhookSlug($validated['payment_method'])),
        ]);

        if (!($result['success'] ?? false)) {
            $transaction->markPaymentFailed();
            return response()->json([
                'message' => $result['message'] ?? 'Le paiement n\'a pas pu être initié.',
            ], 502);
        }

        $transaction->update(['payment_gateway_id' => $result['gateway_reference'] ?? null]);
        $product->update(['status' => 'reserved']);

        return response()->json([
            'message' => 'Redirection vers le paiement.',
            'transaction' => $transaction->fresh()->load(['product', 'seller']),
            'payment_url' => $result['payment_url'],
            'total_amount' => $product->price + $fee,
            'fee' => $fee,
        ], 201);
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

        if ($transaction->payment_status !== 'completed' && $newStatus !== 'cancelled') {
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
                $transaction->update(['order_status' => 'delivered']);
                $transaction->product->update(['status' => 'sold']);
                $user->incrementTrustScore(0.02);
                return response()->json([
                    'message' => 'Commande marquée comme livrée.',
                    'transaction' => $transaction->fresh()->load(['product', 'buyer:id,username,full_name,avatar_url']),
                ]);
            }

            if ($newStatus === 'cancelled') {
                if (!in_array($transaction->order_status, ['pending_payment', 'processing'])) {
                    return response()->json(['message' => 'Cette commande ne peut plus être annulée.'], 422);
                }
                $transaction->update(['order_status' => 'cancelled']);
                $transaction->product->update(['status' => 'active']);
                return response()->json([
                    'message' => 'Commande annulée.',
                    'transaction' => $transaction->fresh()->load(['product', 'buyer:id,username,full_name,avatar_url']),
                ]);
            }

            $transaction->update(['order_status' => $newStatus]);
            return response()->json([
                'message' => 'Statut mis à jour.',
                'transaction' => $transaction->fresh()->load(['product', 'buyer:id,username,full_name,avatar_url']),
            ]);
        }

        if ($transaction->buyer_id === $user->id) {
            if ($newStatus === 'completed' && $transaction->order_status === 'delivered') {
                $transaction->update(['order_status' => 'completed', 'completed_at' => now()]);
                $transaction->seller->incrementTrustScore(0.02);
                return response()->json([
                    'message' => 'Réception confirmée. Merci !',
                    'transaction' => $transaction->fresh()->load(['product', 'seller:id,username,full_name,avatar_url']),
                ]);
            }

            if ($newStatus === 'cancelled' && $transaction->order_status === 'pending_payment') {
                $transaction->update(['order_status' => 'cancelled']);
                $transaction->product->update(['status' => 'active']);
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
        $request->validate(['reason' => ['required', 'string', 'max:1000']]);

        if ($transaction->buyer_id !== $request->user()->id) {
            return response()->json(['message' => 'Non autorisé.'], 403);
        }

        $transaction->update(['security_check' => 'manual_review', 'order_status' => 'disputed']);

        return response()->json(['message' => 'Litige ouvert. Notre équipe va examiner votre cas.']);
    }

    public function webhookWave(Request $request): JsonResponse
    {
        $secret = config('services.wave.webhook_secret');
        $header = $request->header('Wave-Signature');

        if (!$secret || !$header || !$this->verifyWaveSignature($header, $request->getContent(), $secret)) {
            Log::warning('Webhook Wave: signature invalide', ['ip' => $request->ip()]);
            return response()->json(['error' => 'Signature invalide'], 401);
        }

        $payload = $request->json()->all();
        $data = $payload['data'] ?? [];

        if (($payload['type'] ?? null) === 'checkout.session.completed' && ($data['payment_status'] ?? null) === 'succeeded') {
            $transaction = Transaction::find($data['client_reference'] ?? null);
            if ($transaction && $transaction->payment_status !== 'completed') {
                $transaction->markPaid($data['id'] ?? null);
            }
        }

        if (($payload['type'] ?? null) === 'checkout.session.payment_failed') {
            $transaction = Transaction::find($data['client_reference'] ?? null);
            $transaction?->markPaymentFailed();
        }

        return response()->json(['status' => 'received']);
    }

    private function verifyWaveSignature(string $header, string $body, string $secret): bool
    {
        $parts = collect(explode(',', $header))->mapWithKeys(function ($part) {
            [$key, $value] = array_pad(explode('=', $part, 2), 2, null);
            return [$key => $value];
        });

        $timestamp = $parts->get('t');
        $signature = $parts->get('v1');

        if (!$timestamp || !$signature) {
            return false;
        }

        // Anti-rejeu (Wave rejette au-delà de 5 min dans le passé).
        if (abs(time() - (int) $timestamp) > 300) {
            return false;
        }

        return hash_equals(hash_hmac('sha256', $timestamp . $body, $secret), $signature);
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

        if ($transactionRef) {
            $transaction = Transaction::find($transactionRef);
            if ($transaction && $status === 'SUCCESS' && $transaction->payment_status !== 'completed') {
                $transaction->markPaid($request->input('txnid'));
            } elseif ($transaction && $status === 'FAILED') {
                $transaction->markPaymentFailed();
            }
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
}