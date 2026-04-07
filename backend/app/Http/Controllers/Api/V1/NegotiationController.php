<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Negotiation;
use App\Models\Product;
use App\Services\NotificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class NegotiationController extends Controller
{
    public function __construct(private NotificationService $notif) {}
    public function propose(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'product_id' => 'required|exists:products,id',
            'proposed_price' => 'required|numeric|min:100',
            'message' => 'nullable|string|max:500',
        ]);

        $product = Product::findOrFail($validated['product_id']);
        if (!$product->is_negotiable) {
            return response()->json(['message' => 'Ce produit n\'est pas négociable.'], 422);
        }
        if ($product->user_id === $request->user()->id) {
            return response()->json(['message' => 'Vous ne pouvez pas négocier votre propre produit.'], 422);
        }

        $negotiation = Negotiation::create([
            'buyer_id' => $request->user()->id,
            'seller_id' => $product->user_id,
            'product_id' => $product->id,
            'proposed_price' => $validated['proposed_price'],
            'buyer_message' => $validated['message'],
            'expires_at' => now()->addHours(24),
        ]);

        $this->notif->notifyNegotiation(
            $product->user_id,
            $request->user(),
            'proposed',
            $product->title,
            $validated['proposed_price']
        );

        return response()->json(['negotiation' => $negotiation->load('product', 'buyer', 'seller')], 201);
    }

    public function respond(Request $request, Negotiation $negotiation): JsonResponse
    {
        if ($negotiation->seller_id !== $request->user()->id) abort(403);
        if ($negotiation->isExpired()) {
            return response()->json(['message' => 'Cette offre a expiré.'], 422);
        }

        $validated = $request->validate([
            'action' => 'required|in:accept,reject,counter',
            'counter_price' => 'required_if:action,counter|nullable|numeric|min:100',
            'message' => 'nullable|string|max:500',
        ]);

        $negotiation->update([
            'status' => $validated['action'] === 'counter' ? 'countered' : $validated['action'] . 'ed',
            'counter_price' => $validated['counter_price'] ?? null,
            'seller_message' => $validated['message'],
        ]);

        $statusText = match ($validated['action']) {
            'accept' => 'a accepté votre offre',
            'reject' => 'a refusé votre offre',
            'counter' => 'a fait une contre-offre de ' . number_format($validated['counter_price']) . ' F',
        };

        $this->notif->notifyNegotiation(
            $negotiation->buyer_id,
            $request->user(),
            $validated['status'],
            $negotiation->product->title ?? 'Produit',
            $validated['counter_price'] ?? $negotiation->proposed_price
        );

        return response()->json(['negotiation' => $negotiation->fresh()->load('product', 'buyer', 'seller')]);
    }

    public function myNegotiations(Request $request): JsonResponse
    {
        $userId = $request->user()->id;
        $negotiations = Negotiation::where('buyer_id', $userId)
            ->orWhere('seller_id', $userId)
            ->with('product', 'buyer', 'seller')
            ->orderBy('created_at', 'desc')
            ->paginate(20);

        return response()->json($negotiations);
    }
}
