<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Product;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ProductController extends Controller
{
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'title' => ['required', 'string', 'max:200'],
            'description' => ['sometimes', 'string', 'max:5000'],
            'category_id' => ['required', 'uuid', 'exists:categories,id'],
            'price' => ['required', 'numeric', 'min:0'],
            'currency' => ['sometimes', 'in:XOF,EUR,USD'],
            'stock_quantity' => ['sometimes', 'integer', 'min:1'],
            'condition' => ['sometimes', 'in:new,like_new,good,fair'],
            'is_negotiable' => ['sometimes', 'boolean'],
            'video_id' => ['sometimes', 'uuid', 'exists:product_videos,id'],
            'type' => ['sometimes', 'in:product,service'],
            'poster_file' => ['sometimes', 'image', 'mimes:jpeg,png,jpg,webp', 'max:5120'],
            'image_files' => ['sometimes', 'array', 'max:5'],
            'image_files.*' => ['image', 'mimes:jpeg,png,jpg,webp', 'max:5120'],
            'images' => ['sometimes', 'array'],
            'images.*' => ['string', 'max:500'],
            'metadata' => ['sometimes', 'array'],
            'payment_methods' => ['sometimes', 'string'],
            'delivery_option' => ['sometimes', 'in:fixed,contact'],
            'delivery_fee' => ['sometimes', 'integer', 'min:0'],
            // Service-specific fields (stored in metadata)
            'service_type' => ['sometimes', 'string', 'in:online,in_person,both'],
            'availability' => ['sometimes', 'string'],
            'duration' => ['sometimes', 'string'],
            'service_area' => ['sometimes', 'string', 'max:200'],
            'experience_years' => ['sometimes'],
            'price_type' => ['sometimes', 'string', 'in:fixed,starting,hourly,quote'],
        ]);

        // Pack service-specific fields into metadata
        if (($validated['type'] ?? 'product') === 'service') {
            $serviceFields = ['service_type', 'availability', 'duration', 'service_area', 'experience_years', 'price_type'];
            $meta = $validated['metadata'] ?? [];
            foreach ($serviceFields as $field) {
                if (isset($validated[$field]) && $validated[$field] !== '') {
                    $meta[$field] = $validated[$field];
                }
                unset($validated[$field]);
            }
            $validated['metadata'] = $meta;
        } else {
            // Clean up service fields for products
            unset($validated['service_type'], $validated['availability'], $validated['duration'],
                  $validated['service_area'], $validated['experience_years'], $validated['price_type']);
        }

        // Handle poster image upload (main product image)
        if ($request->hasFile('poster_file')) {
            $posterPath = $request->file('poster_file')->store('products/posters', 'public');
            $validated['poster_url'] = $posterPath;
        }

        // Handle payment_methods (comes as JSON string from FormData)
        if (isset($validated['payment_methods']) && is_string($validated['payment_methods'])) {
            $decoded = json_decode($validated['payment_methods'], true);
            $validated['payment_methods'] = is_array($decoded) ? $decoded : [];
        }

        // Handle image file uploads
        if ($request->hasFile('image_files')) {
            $imagePaths = [];
            foreach ($request->file('image_files') as $imageFile) {
                $path = $imageFile->store('products/images', 'public');
                $imagePaths[] = $path;
            }
            // Merge with any existing image paths
            $existingImages = $validated['images'] ?? [];
            $validated['images'] = array_merge($existingImages, $imagePaths);
        }

        // Remove file fields from validated data (not model fields)
        unset($validated['image_files'], $validated['poster_file']);

        $validated['user_id'] = $request->user()->id;
        $validated['status'] = 'active';

        $product = Product::create($validated);
        $product->load(['category', 'video', 'user']);

        return response()->json([
            'message' => 'Produit créé avec succès.',
            'product' => $product,
        ], 201);
    }

    public function show(Product $product): JsonResponse
    {
        $product->load(['user', 'category', 'video']);

        $isLiked = false;
        $isSaved = false;

        if (auth()->check()) {
            $isLiked = $product->likedByUsers()->where('user_id', auth()->id())->exists();
            $isSaved = $product->savedByUsers()->where('user_id', auth()->id())->exists();
        }

        return response()->json([
            'product' => $product,
            'seller' => [
                'id' => $product->user->id,
                'full_name' => $product->user->full_name,
                'username' => $product->user->username,
                'avatar_url' => $product->user->avatar_url,
                'trust_score' => $product->user->trust_score,
                'trust_badge' => $product->user->trust_badge,
                'products_count' => $product->user->products()->active()->count(),
                'member_since' => $product->user->created_at->format('M Y'),
            ],
            'is_liked' => $isLiked,
            'is_saved' => $isSaved,
        ]);
    }

    public function update(Request $request, Product $product): JsonResponse
    {
        if (!$product->isOwnedBy($request->user()) && !$request->user()->isAdmin()) {
            return response()->json(['message' => 'Non autorisé.'], 403);
        }

        $validated = $request->validate([
            'title' => ['sometimes', 'string', 'max:200'],
            'description' => ['sometimes', 'string', 'max:5000'],
            'price' => ['sometimes', 'numeric', 'min:0'],
            'stock_quantity' => ['sometimes', 'integer', 'min:0'],
            'condition' => ['sometimes', 'in:new,like_new,good,fair'],
            'is_negotiable' => ['sometimes', 'boolean'],
            'status' => ['sometimes', 'in:draft,active,sold,reserved,expired,paused,disabled'],
        ]);

        $product->update($validated);

        return response()->json([
            'message' => 'Produit mis à jour.',
            'product' => $product->fresh()->load(['category', 'video']),
        ]);
    }

    public function destroy(Request $request, Product $product): JsonResponse
    {
        if (!$product->isOwnedBy($request->user()) && !$request->user()->isAdmin()) {
            return response()->json(['message' => 'Non autorisé.'], 403);
        }

        $product->delete();

        return response()->json([
            'message' => 'Produit supprimé.',
        ]);
    }

    public function myProducts(Request $request): JsonResponse
    {
        $products = $request->user()
            ->products()
            ->with(['category', 'video'])
            ->latest()
            ->paginate(20);

        return response()->json($products);
    }
}
