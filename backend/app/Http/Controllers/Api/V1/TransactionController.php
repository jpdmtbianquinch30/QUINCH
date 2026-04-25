<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\Transaction;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

class TransactionController extends Controller
{
    public function initiate(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'product_id' => ['required', 'uuid', 'exists:products,id'],
            'payment_method' => ['required', 'in:orange_money,wave,free_money,cash_delivery'],
            'delivery_type' => ['required', 'in:pickup,delivery,meetup'],
            'delivery_address' => ['required_if:delivery_type,delivery', 'array'],
        ]);

        $product = Product::findOrFail($validated['product_id']);

        if ($product->user_id === $request->user()->id) {
            return response()->json(['message' => 'Vous ne pouvez pas acheter votre propre produit.'], 422);
        }

        if ($product->status !== 'active') {
            return response()->json(['message' => 'Ce produit n\'est plus disponible.'], 422);
        }

        $feeRate = $validated['payment_method'] === 'cash_delivery' ? 0 : 0.025;
        $fee = round($product->price * $feeRate, 2);

        $transaction = Transaction::create([
            'buyer_id' => $request->user()->id,
            'seller_id' => $product->user_id,
            'product_id' => $product->id,
            'amount' => $product->price,
            'currency' => 'XOF',
            'payment_method' => $validated['payment_method'],
            'payment_status' => 'pending',
            'security_check' => 'pending',
            'delivery_type' => $validated['delivery_type'],
            'delivery_address' => $validated['delivery_address'] ?? null,
            'transaction_fee' => $fee,
        ]);

        $product->update(['status' => 'reserved']);

        $paymentUrl = null;
        if ($validated['payment_method'] !== 'cash_delivery') {
            $paymentUrl = url("/api/v1/transactions/{$transaction->id}/confirm");
        }

        return response()->json([
            'message' => 'Transaction initiée.',
            'transaction' => $transaction->load(['product', 'seller']),
            'payment_url' => $paymentUrl,
            'total_amount' => $product->price + $fee,
            'fee' => $fee,
        ], 201);
    }

    public function confirm(Request $request, Transaction $transaction): JsonResponse
    {
        if ($transaction->buyer_id !== $request->user()->id && !$request->user()->isAdmin()) {
            return response()->json(['message' => 'Non autorisé.'], 403);
        }

        $transaction->markCompleted();
        $transaction->product->update(['status' => 'sold']);
        $transaction->seller->incrementTrustScore(0.02);

        return response()->json([
            'message' => 'Paiement confirmé.',
            'transaction' => $transaction->fresh()->load(['product', 'seller', 'buyer']),
        ]);
    }

    /**
     * Enhanced history with stats
     */
    public function history(Request $request): JsonResponse
    {
        $user = $request->user();

        $purchases = $user->purchasedTransactions()
            ->with(['product:id,title,slug,price,currency', 'seller:id,username,full_name,avatar_url'])
            ->latest()
            ->paginate(50, ['*'], 'purchases_page');

        $sales = $user->soldTransactions()
            ->with(['product:id,title,slug,price,currency', 'buyer:id,username,full_name,avatar_url'])
            ->latest()
            ->paginate(50, ['*'], 'sales_page');

        // Compute stats
        $allPurchases = $user->purchasedTransactions()->get();
        $allSales = $user->soldTransactions()->get();

        $stats = [
            'total_spent' => $allPurchases->sum('amount'),
            'total_earned' => $allSales->sum('amount'),
            'total_fees' => $allSales->sum('transaction_fee'),
            'purchases_count' => $allPurchases->count(),
            'sales_count' => $allSales->count(),
            'completed_purchases' => $allPurchases->where('payment_status', 'completed')->count(),
            'completed_sales' => $allSales->where('payment_status', 'completed')->count(),
            'pending_purchases' => $allPurchases->whereIn('payment_status', ['pending', 'processing'])->count(),
            'pending_sales' => $allSales->whereIn('payment_status', ['pending', 'processing'])->count(),
            'cancelled_count' => $allPurchases->where('payment_status', 'cancelled')->count()
                + $allSales->where('payment_status', 'cancelled')->count(),
        ];

        return response()->json([
            'purchases' => $purchases,
            'sales' => $sales,
            'stats' => $stats,
        ]);
    }

    /**
     * Get single transaction detail
     */
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

    /**
     * Seller updates order status (accept, ship, deliver)
     */
    public function updateStatus(Request $request, Transaction $transaction): JsonResponse
    {
        $user = $request->user();
        $validated = $request->validate([
            'status' => ['required', 'in:processing,shipped,delivered,completed,cancelled'],
            'note' => ['sometimes', 'string', 'max:500'],
        ]);

        $newStatus = $validated['status'];

        // Seller actions
        if ($transaction->seller_id === $user->id) {
            $allowed = ['processing', 'shipped', 'delivered', 'cancelled'];
            if (!in_array($newStatus, $allowed)) {
                return response()->json(['message' => 'Action non autorisée pour le vendeur.'], 422);
            }

            // Seller accepts order
            if ($newStatus === 'processing' && $transaction->payment_status === 'pending') {
                $transaction->update(['payment_status' => 'processing']);
                return response()->json([
                    'message' => 'Commande acceptée.',
                    'transaction' => $transaction->fresh()->load(['product', 'buyer:id,username,full_name,avatar_url']),
                ]);
            }

            // Seller ships
            if ($newStatus === 'shipped' && in_array($transaction->payment_status, ['pending', 'processing'])) {
                $transaction->update(['payment_status' => 'processing', 'security_check' => 'passed']);
                return response()->json([
                    'message' => 'Commande marquée comme expédiée.',
                    'transaction' => $transaction->fresh()->load(['product', 'buyer:id,username,full_name,avatar_url']),
                ]);
            }

            // Seller marks delivered
            if ($newStatus === 'delivered') {
                $transaction->markCompleted();
                $transaction->product->update(['status' => 'sold']);
                $user->incrementTrustScore(0.02);
                return response()->json([
                    'message' => 'Commande marquée comme livrée.',
                    'transaction' => $transaction->fresh()->load(['product', 'buyer:id,username,full_name,avatar_url']),
                ]);
            }

            // Seller cancels
            if ($newStatus === 'cancelled' && in_array($transaction->payment_status, ['pending', 'processing'])) {
                $transaction->update(['payment_status' => 'cancelled']);
                $transaction->product->update(['status' => 'active']);
                return response()->json([
                    'message' => 'Commande annulée.',
                    'transaction' => $transaction->fresh()->load(['product', 'buyer:id,username,full_name,avatar_url']),
                ]);
            }
        }

        // Buyer actions
        if ($transaction->buyer_id === $user->id) {
            // Buyer confirms receipt
            if ($newStatus === 'completed' && $transaction->payment_status === 'processing') {
                $transaction->markCompleted();
                $transaction->product->update(['status' => 'sold']);
                $transaction->seller->incrementTrustScore(0.02);
                return response()->json([
                    'message' => 'Réception confirmée. Merci!',
                    'transaction' => $transaction->fresh()->load(['product', 'seller:id,username,full_name,avatar_url']),
                ]);
            }

            // Buyer cancels pending order
            if ($newStatus === 'cancelled' && $transaction->payment_status === 'pending') {
                $transaction->update(['payment_status' => 'cancelled']);
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
        $request->validate([
            'reason' => ['required', 'string', 'max:1000'],
        ]);

        if ($transaction->buyer_id !== $request->user()->id) {
            return response()->json(['message' => 'Non autorisé.'], 403);
        }

        $transaction->update(['security_check' => 'manual_review']);

        return response()->json([
            'message' => 'Litige ouvert. Notre équipe va examiner votre cas.',
        ]);
    }

public function webhookOrangeMoney(Request $request): JsonResponse
{
    // Vérifier signature Orange Money
    $signature = $request->header('X-Orange-Signature');
    $secret = config('services.orange_money.webhook_secret');

    if ($secret && $signature !== hash_hmac('sha256', $request->getContent(), $secret)) {
        Log::warning('Webhook Orange Money: signature invalide', ['ip' => $request->ip()]);
        return response()->json(['error' => 'Signature invalide'], 401);
    }

    $transactionRef = $request->input('transaction_id') ?? $request->input('order_id');
    if ($transactionRef) {
        $transaction = Transaction::where('reference', $transactionRef)->first();
        if ($transaction && $request->input('status') === 'SUCCESS') {
            $transaction->update(['status' => 'completed']);
        }
    }

    return response()->json(['status' => 'received']);
}

public function webhookWave(Request $request): JsonResponse
{
    $signature = $request->header('X-Wave-Signature');
    $secret = config('services.wave.webhook_secret');

    if ($secret && $signature !== hash_hmac('sha256', $request->getContent(), $secret)) {
        Log::warning('Webhook Wave: signature invalide', ['ip' => $request->ip()]);
        return response()->json(['error' => 'Signature invalide'], 401);
    }

    $transactionRef = $request->input('client_reference');
    if ($transactionRef) {
        $transaction = Transaction::where('reference', $transactionRef)->first();
        if ($transaction && $request->input('payment_status') === 'succeeded') {
            $transaction->update(['status' => 'completed']);
        }
    }

    return response()->json(['status' => 'received']);
}

public function webhookFreeMoney(Request $request): JsonResponse
{
    $signature = $request->header('X-FreeMoney-Signature');
    $secret = config('services.free_money.webhook_secret');

    if ($secret && $signature !== hash_hmac('sha256', $request->getContent(), $secret)) {
        Log::warning('Webhook FreeMoney: signature invalide', ['ip' => $request->ip()]);
        return response()->json(['error' => 'Signature invalide'], 401);
    }

    $transactionRef = $request->input('reference');
    if ($transactionRef) {
        $transaction = Transaction::where('reference', $transactionRef)->first();
        if ($transaction && $request->input('status') === 'PAID') {
            $transaction->update(['status' => 'completed']);
        }
    }

    return response()->json(['status' => 'received']);
}
}
