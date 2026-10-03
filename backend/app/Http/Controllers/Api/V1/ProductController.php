<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\UserBadge;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use App\Services\PaymentGateway\PaymentGatewayFactory;
use Illuminate\Support\Facades\Log;
use App\Support\VerifiesWaveWebhook;
use App\Support\ResolvesFrontendUrl;


class ProductController extends Controller
{
    use VerifiesWaveWebhook;
    use ResolvesFrontendUrl;
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
        // "Publier" publie tout de suite, exactement comme "Enregistrer en
        // brouillon" enregistre tout de suite - seule la visibilité change
        // (draft = vendeur seul, active = public). SAUF un cas : une vidéo
        // est jointe (video_id) et le compte n'est pas premium. Une vidéo
        // active la visibilité du produit dans le feed vidéo — réservé par
        // défaut au premium, ou payable à l'unité (150 F) pour un compte
        // gratuit. Pas de vidéo, ou compte premium -> toujours gratuit et
        // immédiat, comme avant.
        $hasVideo = !empty($validated['video_id']);

        if ($hasVideo && !$isPremium) {
            $validated['status'] = 'draft';
            $validated['listing_fee_status'] = 'pending';
            $validated['listing_fee_amount'] = $this->listingFee();

            $product = Product::create($validated);
            $product->load(['category', 'video', 'user']);

            return $this->startListingPayment($request, $product);
        }

        $validated['status'] = 'active';
        $validated['listing_fee_status'] = 'none';

        $product = Product::create($validated);

        // @pseudo dans le titre / la description : on prévient les personnes
        // mentionnées (uniquement si l'annonce est réellement en ligne).
        if ($product->status === 'active') {
            try {
                app(\App\Services\NotificationService::class)->notifyMentions($product, $request->user());
            } catch (\Throwable $e) {
                Log::warning('notifyMentions a échoué', ['error' => $e->getMessage()]);
            }
        }
        $product->load(['category', 'video', 'user']);

        return response()->json([
            'message' => 'Produit créé avec succès.',
            'product' => $product,
        ], 201);
    }

        /** Frais de publication (F CFA) d'une annonce avec vidéo pour un compte gratuit. */
    private function listingFee(): int
    {
        return (int) config('quinch.premium.listing_fee_with_video', 150);
    }

    /**
     * Crée la session de paiement Wave des frais de publication. L'annonce reste
     * en "draft" tant que le webhook Wave n'a pas confirmé le paiement.
     */
    private function startListingPayment(Request $request, Product $product, int $httpStatus = 201): JsonResponse
    {
        $fee = $this->listingFee();

        if ($product->listing_fee_status !== 'pending' || (int) $product->listing_fee_amount !== $fee) {
            $product->update(['listing_fee_status' => 'pending', 'listing_fee_amount' => $fee]);
        }

        try {
            $gateway = PaymentGatewayFactory::create('wave');
        } catch (\InvalidArgumentException $e) {
            Log::error('Publication vidéo: passerelle Wave indisponible', ['error' => $e->getMessage()]);
            $product->update(['listing_fee_status' => 'failed']);

            return response()->json([
                'message' => "Le paiement n'est pas disponible pour le moment. Vous pouvez publier sans vidéo, ou réessayer plus tard.",
            ], 422);
        }

        $frontendUrl = $this->resolveFrontendUrl($request);

        $result = $gateway->initiatePayment([
            'amount' => $fee,
            'transaction_id' => 'listing_' . $product->id,
            'success_url' => "{$frontendUrl}/feed",
            'error_url' => "{$frontendUrl}/sell",
            'notif_url' => url('/api/v1/webhooks/wave-listing'),
        ]);

        if (!($result['success'] ?? false)) {
            $product->update(['listing_fee_status' => 'failed']);

            return response()->json([
                'message' => $result['message'] ?? "Le paiement des {$fee} F n'a pas pu être initié.",
            ], 502);
        }

        $product->update(['listing_fee_gateway_id' => $result['gateway_reference'] ?? null]);

        return response()->json([
            'message' => "Un dernier pas : réglez les {$fee} F de publication vidéo pour mettre votre annonce en ligne.",
            'product' => $product,
            'payment_url' => $result['payment_url'],
            'fee' => $fee,
        ], $httpStatus);
    }

    /**
     * Publie un brouillon. Seul chemin pour mettre un brouillon en ligne :
     * - avec vidéo + compte gratuit + frais non payés -> paiement Wave de 150 F ;
     * - sinon -> publication immédiate et gratuite.
     */
    public function publish(Request $request, Product $product): JsonResponse
    {
        $user = $request->user();

        if (!$product->isOwnedBy($user)) {
            return response()->json(['message' => 'Non autorisé.'], 403);
        }

        if ($product->status !== 'draft') {
            return response()->json(['message' => 'Seul un brouillon peut être publié.'], 422);
        }

        $needsFee = !empty($product->video_id)
            && !$user->isPremiumActive()
            && $product->listing_fee_status !== 'paid';

        if ($needsFee) {
            return $this->startListingPayment($request, $product->load(['category', 'video', 'user']), 200);
        }

        $product->update([
            'status' => 'active',
            'listing_fee_status' => $product->listing_fee_status === 'paid' ? 'paid' : 'none',
        ]);

        try {
            app(\App\Services\NotificationService::class)->notifyMentions($product->fresh(), $user);
        } catch (\Throwable $e) {
            Log::warning('notifyMentions a échoué', ['error' => $e->getMessage()]);
        }

        return response()->json([
            'message' => 'Annonce publiée.',
            'product' => $product->fresh()->load(['category', 'video', 'user']),
        ]);
    }

    /**
     * Transitions de statut interdites au propriétaire (un admin peut tout faire).
     * @return string|null message d'erreur, ou null si la transition est permise
     */
    private function statusTransitionError(\App\Models\User $user, Product $product, string $to): ?string
    {
        if ($user->isAdmin()) {
            return null;
        }

        // Un brouillon ne se publie QUE par /publish (qui gère les frais).
        if ($product->status === 'draft') {
            return 'Utilisez « Publier » pour mettre ce brouillon en ligne.';
        }

        // Retirée par la modération : seul un admin peut la remettre.
        if ($product->status === 'disabled') {
            return 'Cette annonce a été désactivée par la modération.';
        }

        if (in_array($to, ['draft', 'disabled', 'expired'], true)) {
            return 'Changement de statut non autorisé.';
        }

        return null;
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

        if (!\Illuminate\Support\Str::isUuid($productId)) {
            return response()->json(['status' => 'ignored']);
        }

        if (($payload['type'] ?? null) === 'checkout.session.completed' && ($data['payment_status'] ?? null) === 'succeeded') {
            \Illuminate\Support\Facades\DB::transaction(function () use ($productId, $data) {
                // Verrou : deux webhooks simultanés ne peuvent pas traiter la même annonce.
                $product = Product::whereKey($productId)->lockForUpdate()->first();

                if (!$product) {
                    Log::warning('Wave listing: paiement reçu pour une annonce introuvable (supprimée ?) — remboursement à étudier', [
                        'product_id' => $productId,
                    ]);
                    return;
                }

                if ($product->listing_fee_status === 'paid') {
                    return; // déjà traité (idempotent)
                }

                if (!in_array($product->listing_fee_status, ['pending', 'failed'], true)) {
                    Log::warning('Wave listing: paiement reçu pour une annonce sans frais en attente — remboursement à étudier', [
                        'product_id' => $product->id,
                    ]);
                    return;
                }

                // Le montant payé ne doit pas être inférieur aux frais attendus.
                $expected = (int) ($product->listing_fee_amount ?: config('quinch.premium.listing_fee_with_video', 150));
                if (isset($data['amount']) && (int) round((float) $data['amount']) < $expected) {
                    Log::critical('Wave listing: montant payé inférieur aux frais attendus', [
                        'product_id' => $product->id,
                        'expected' => $expected,
                        'received' => $data['amount'],
                    ]);
                    return;
                }

                // Un paiement réussi fait foi, même si une tentative précédente était "failed".
                $product->update([
                    'status' => 'active',
                    'listing_fee_status' => 'paid',
                    'listing_fee_gateway_id' => $data['id'] ?? $product->listing_fee_gateway_id,
                ]);

                try {
                    if ($product->user) {
                        app(\App\Services\NotificationService::class)->notifyMentions($product->fresh(), $product->user);
                    }
                } catch (\Throwable $e) {
                    Log::warning('notifyMentions a échoué', ['error' => $e->getMessage()]);
                }
            });
        }

        if (($payload['type'] ?? null) === 'checkout.session.payment_failed') {
            Product::where('id', $productId)->where('listing_fee_status', 'pending')->update(['listing_fee_status' => 'failed']);
        }

        return response()->json(['status' => 'received']);
    }

    public function show(Request $request, Product $product): JsonResponse
    {
        $product->load(['user', 'category', 'video']);

        $isLiked = false;
        $isSaved = false;

        // Route publique : le guard par défaut est "web" (session), qui ne voit
        // jamais un token Bearer. Il faut demander explicitement Sanctum.
        $authUser = $request->user('sanctum');

        if ($authUser) {
            $isLiked = $product->likedByUsers()->where('user_id', $authUser->id)->exists();
            $isSaved = \App\Models\FavoriteItem::where('user_id', $authUser->id)->where('product_id', $product->id)->exists();
        }

        $badges = UserBadge::where('user_id', $product->user->id)->active()->get()->map(fn ($b) => [
            'type' => $b->badge_type,
            'name' => UserBadge::badgeDefinitions()[$b->badge_type]['name'] ?? $b->badge_type,
            'icon' => UserBadge::badgeDefinitions()[$b->badge_type]['icon'] ?? 'stars',
            'color' => UserBadge::badgeDefinitions()[$b->badge_type]['color'] ?? '#666',
            'description' => UserBadge::badgeDefinitions()[$b->badge_type]['description'] ?? '',
        ]);

        return response()->json([
            'product' => $product,
            'seller' => [
                'id' => $product->user->id,
                'full_name' => $product->user->full_name,
                'username' => $product->user->username,
                'avatar_url' => $product->user->avatar_url,
                'city' => $product->user->city,
                'kyc_status' => $product->user->kyc_status,
                'account_age_days' => $product->user->account_age_days,
                'trust_score' => $product->user->trust_score,
                'trust_badge' => $product->user->trust_badge,
                'products_count' => $product->user->products()->active()->count(),
                'member_since' => $product->user->created_at->format('M Y'),
                'is_premium' => $product->user->isPremiumActive(),
                'badges' => $badges,
                'is_online' => $product->user->is_online,
                'last_seen_at' => $product->user->last_seen_at?->toISOString(),
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

        // Empêche de contourner les frais de publication (brouillon -> active)
        // ou la modération (disabled -> active) par un simple PUT.
        if (isset($validated['status']) && $validated['status'] !== $product->status) {
            $error = $this->statusTransitionError($request->user(), $product, $validated['status']);

            if ($error !== null) {
                return response()->json(['message' => $error, 'error' => 'invalid_status_transition'], 422);
            }
        }

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
