<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Product;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use App\Services\PaymentGateway\PaymentGatewayFactory;
use Illuminate\Support\Facades\Log;
use App\Support\VerifiesWaveWebhook;


class ProductController extends Controller
{
    use VerifiesWaveWebhook;
        public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'title' => ['required', 'string', 'max:200'],
            'description' => ['sometimes', 'string', 'max:5000'],
            'category_id' => ['required', 'uuid', 'exists:categories,id'],
            'price' => ['required', 'numeric', 'min:0'],
            'intent' => ['sometimes', 'in:draft,publish'],
            'currency' => ['sometimes', 'in:XOF,EUR,USD'],
            'stock_quantity' => ['sometimes', 'integer', 'min:1'],
            'condition' => ['sometimes', 'in:new,like_new,good,fair'],
            'is_negotiable' => ['sometimes', 'boolean'],
            'video_id' => ['sometimes', 'uuid', 'exists:product_videos,id'],
            'type' => ['sometimes', 'in:product,service'],
            'poster_file' => ['required_without_all:image_files,video_id', 'sometimes', 'image', 'mimes:jpeg,png,jpg,webp', 'max:5120'],
            'image_files' => ['required_without_all:poster_file,video_id', 'sometimes', 'array', 'max:10'],
            'image_files.*' => ['image', 'mimes:jpeg,png,jpg,webp', 'max:5120'],
            'images' => ['sometimes', 'array'],
            'images.*' => ['string', 'max:500'],
            'metadata' => ['sometimes', 'array'],
            'payment_methods' => ['sometimes', 'string'],
            'delivery_option' => ['sometimes', 'in:fixed,contact'],
            'delivery_fee' => ['sometimes', 'integer', 'min:0'],
            'service_type' => ['sometimes', 'string', 'in:online,in_person,both'],
            'availability' => ['sometimes', 'string'],
            'duration' => ['sometimes', 'string'],
            'service_area' => ['sometimes', 'string', 'max:200'],
            'experience_years' => ['sometimes'],
            'price_type' => ['sometimes', 'string', 'in:fixed,starting,hourly,quote'],
        ], [
            'poster_file.required_without_all' => 'Ajoutez au moins une photo ou une video.',
            'image_files.required_without_all' => 'Ajoutez au moins une photo ou une video.',
        ]);

        $user = $request->user();
        $isPremium = $user->isPremiumActive();

        // ─── Limite de photos ────────────────────────────────────────────
        // La couverture (poster) est toujours à part, jamais comptée dans
        // cette limite : jusqu'à 5 photos supplémentaires pour un compte
        // non-premium (6 au total), jusqu'à 10 pour un compte premium (11
        // au total).
        $additionalCount = count($request->file('image_files', []));
        $maxAdditional = $isPremium
            ? config('quinch.premium.premium_additional_photos_max')
            : config('quinch.premium.free_additional_photos_max');

        if ($additionalCount > $maxAdditional) {
            return response()->json([
                'message' => $isPremium
                    ? "Vous pouvez ajouter jusqu'à {$maxAdditional} photos supplémentaires (en plus de la couverture)."
                    : "Les comptes gratuits sont limités à {$maxAdditional} photos supplémentaires (en plus de la couverture). Passez Premium pour aller jusqu'à " . config('quinch.premium.premium_additional_photos_max') . '.',
            ], 422);
        }

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
            unset($validated['service_type'], $validated['availability'], $validated['duration'],
                  $validated['service_area'], $validated['experience_years'], $validated['price_type']);
        }

        if ($request->hasFile('poster_file')) {
            $validated['poster_url'] = $request->file('poster_file')->store('products/posters', 'public');
        }

        if (isset($validated['payment_methods']) && is_string($validated['payment_methods'])) {
            $decoded = json_decode($validated['payment_methods'], true);
            $validated['payment_methods'] = is_array($decoded) ? $decoded : [];
        }

        if ($request->hasFile('image_files')) {
            $imagePaths = [];
            foreach ($request->file('image_files') as $imageFile) {
                $imagePaths[] = $imageFile->store('products/images', 'public');
            }
            $validated['images'] = array_merge($validated['images'] ?? [], $imagePaths);
        }

        unset($validated['image_files'], $validated['poster_file']);

        $validated['user_id'] = $user->id;

        $intent = $validated['intent'] ?? 'publish';
        unset($validated['intent']);

        // ─── Enregistrer comme brouillon (aucun paiement tenté) ────────────
        if ($intent === 'draft') {
            $validated['status'] = 'draft';
            $validated['listing_fee_status'] = 'none';

            $product = Product::create($validated);
            $product->load(['category', 'video']);

            return response()->json([
                'message' => 'Brouillon enregistré. Vous pourrez le publier plus tard.',
                'product' => $product,
            ], 201);
        }

        // ─── Publication directe ────────────────────────────────────────
        // Sur demande explicite : "Publier" doit toujours publier tout de
        // suite, exactement comme "Enregistrer en brouillon" enregistre tout
        // de suite - seule la visibilité change (draft = vendeur seul,
        // active = public). Le système de frais de publication payants
        // (Wave) reste dans le code (webhookWaveListingFee ci-dessous,
        // config quinch.premium.listing_fee_*) mais n'est plus déclenché
        // depuis ce endpoint - à réactiver explicitement si le produit
        // business le demande un jour.
        $validated['status'] = 'active';
        $validated['listing_fee_status'] = 'none';

        $product = Product::create($validated);
        $product->load(['category', 'video', 'user']);

        return response()->json([
            'message' => 'Produit créé avec succès.',
            'product' => $product,
        ], 201);
    }

    public function webhookWaveListingFee(Request $request): JsonResponse
    {
        $secret = $this->waveWebhookSecret();
        $header = $request->header('Wave-Signature');

        if (!$secret || !$header || !$this->verifyWaveSignature($header, $request->getContent(), $secret)) {
            \Illuminate\Support\Facades\Log::warning('Webhook Wave Listing Fee: signature invalide', ['ip' => $request->ip()]);
            return response()->json(['error' => 'Signature invalide'], 401);
        }

        $payload = $request->json()->all();
        $data = $payload['data'] ?? [];
        $clientReference = $data['client_reference'] ?? null;

        if (!$clientReference || !str_starts_with($clientReference, 'listing_')) {
            return response()->json(['status' => 'ignored']);
        }

        $productId = substr($clientReference, strlen('listing_'));

        if (($payload['type'] ?? null) === 'checkout.session.completed' && ($data['payment_status'] ?? null) === 'succeeded') {
            $product = Product::find($productId);
            if ($product && $product->listing_fee_status === 'pending') {
                $product->update([
                    'status' => 'active',
                    'listing_fee_status' => 'paid',
                    'listing_fee_gateway_id' => $data['id'] ?? $product->listing_fee_gateway_id,
                ]);
            }
        }

        if (($payload['type'] ?? null) === 'checkout.session.payment_failed') {
            Product::where('id', $productId)->where('listing_fee_status', 'pending')->update(['listing_fee_status' => 'failed']);
        }

        return response()->json(['status' => 'received']);
    }

    public function show(Product $product): JsonResponse
    {
        $product->load(['user', 'category', 'video']);

        $isLiked = false;
        $isSaved = false;

        if (auth()->check()) {
            $isLiked = $product->likedByUsers()->where('user_id', auth()->id())->exists();
            $isSaved = \App\Models\FavoriteItem::where('user_id', auth()->id())->where('product_id', $product->id)->exists();
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
                'is_premium' => $product->user->isPremiumActive(),
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
