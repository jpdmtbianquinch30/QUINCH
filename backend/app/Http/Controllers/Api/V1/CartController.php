<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\CartItem;
use App\Models\Product;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CartController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $items = CartItem::where('user_id', $request->user()->id)
            ->with(['product.video', 'product.category', 'product.user:id,full_name,username,avatar_url,trust_score'])
            ->orderBy('created_at', 'desc')
            ->get();

        // Transform items to include delivery and payment info
        $transformedItems = $items->map(function ($item) {
            $product = $item->product;
            return [
                'id' => $item->id,
                'product_id' => $item->product_id,
                'quantity' => $item->quantity,
                'price_at_add' => $item->price_at_add,
                'product' => [
                    'id' => $product->id,
                    'title' => $product->title,
                    'slug' => $product->slug,
                    'price' => $product->price,
                    'formatted_price' => $product->formatted_price,
                    'condition' => $product->condition,
                    'status' => $product->status,
                    'type' => $product->type ?? 'product',
                    'poster' => $product->poster_full_url,
                    'images' => $product->images,
                    'video' => $product->video ? [
                        'thumbnail' => $product->video->thumbnail_path
                            ? '/api/v1/videos/' . $product->video->id . '/thumbnail'
                            : null,
                    ] : null,
                    'category' => $product->category ? ['name' => $product->category->name] : null,
                    'seller' => $product->user ? [
                        'id' => $product->user->id,
                        'full_name' => $product->user->full_name,
                        'username' => $product->user->username,
                        'avatar_url' => $product->user->avatar_url,
                    ] : null,
                    'delivery_option' => $product->delivery_option ?? 'contact',
                    'delivery_fee' => $product->delivery_fee ?? 0,
                    'payment_methods' => $product->payment_methods ?? [],
                ],
            ];
        });

        $subtotal = $items->sum(fn ($item) => $item->price_at_add * $item->quantity);
        $deliveryTotal = $items->sum(function ($item) {
            $product = $item->product;
            if (($product->delivery_option ?? 'contact') === 'fixed' && $product->delivery_fee > 0) {
                return $product->delivery_fee;
            }
            return 0;
        });

        return response()->json([
            'items' => $transformedItems,
            'subtotal' => $subtotal,
            'delivery_total' => $deliveryTotal,
            'total' => $subtotal + $deliveryTotal,
            'count' => $items->count(),
        ]);
    }

    public function add(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'product_id' => 'required|exists:products,id',
            'quantity' => 'sometimes|integer|min:1|max:10',
        ]);

        $product = Product::findOrFail($validated['product_id']);

        $item = CartItem::updateOrCreate(
            ['user_id' => $request->user()->id, 'product_id' => $product->id],
            [
                'quantity' => $validated['quantity'] ?? 1,
                'price_at_add' => $product->price,
                'reserved_until' => now()->addMinutes(15),
            ]
        );

        return response()->json([
            'message' => 'Produit ajouté au panier.',
            'item' => $item->load('product'),
            'cart_count' => CartItem::where('user_id', $request->user()->id)->count(),
        ]);
    }

    public function update(Request $request, CartItem $cartItem): JsonResponse
    {
        if ($cartItem->user_id !== $request->user()->id) abort(403);

        $validated = $request->validate(['quantity' => 'required|integer|min:1|max:10']);
        $cartItem->update(['quantity' => $validated['quantity']]);

        return response()->json(['message' => 'Quantité mise à jour.', 'item' => $cartItem]);
    }

    public function remove(Request $request, CartItem $cartItem): JsonResponse
    {
        if ($cartItem->user_id !== $request->user()->id) abort(403);

        $cartItem->delete();
        return response()->json([
            'message' => 'Produit retiré du panier.',
            'cart_count' => CartItem::where('user_id', $request->user()->id)->count(),
        ]);
    }

    public function clear(Request $request): JsonResponse
    {
        CartItem::where('user_id', $request->user()->id)->delete();
        return response()->json(['message' => 'Panier vidé.']);
    }

    public function count(Request $request): JsonResponse
    {
        return response()->json([
            'count' => CartItem::where('user_id', $request->user()->id)->count(),
        ]);
    }
}
