<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\Transaction;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Classements : 100 meilleurs vendeurs du mois, 100 meilleurs acheteurs du
 * mois, 100 produits les plus vus, 100 profils les plus visites.
 *
 * Regle commune aux 4 : reserve aux comptes Premium, a la fois pour
 * consulter ET pour y figurer. Figurer dans un classement est un choix
 * explicite (ranking_opt_in) — un vendeur en tete des ventes qui n'a pas
 * postule n'apparait nulle part, meme classe premier en interne.
 */
class RankingController extends Controller
{
    private const LIMIT = 100;

    private function requirePremium(Request $request): void
    {
        if (!$request->user()->isPremiumActive()) {
            abort(403, 'Les classements sont reserves aux comptes Premium.');
        }
    }

    // Anonymise une entree si l'utilisateur classe a choisi de rester
    // anonyme — le rang et les chiffres restent visibles, seule son
    // identite (nom, pseudo, avatar) est masquee.
    private function presentUser(User $user, int $rank, array $metric): array
    {
        $anonymous = (bool) $user->ranking_anonymous;

        return array_merge([
            'rank' => $rank,
            'anonymous' => $anonymous,
            'username' => $anonymous ? null : $user->username,
            'full_name' => $anonymous ? 'Utilisateur anonyme' : $user->full_name,
            'avatar_url' => $anonymous ? null : $user->avatar_url,
            // Pas de badges pour une entree anonyme : afficher "Client Fidele"
            // a cote d'un profil masque reveindrait a partiellement lever
            // l'anonymat choisi.
            'badges' => $anonymous ? [] : \App\Models\UserBadge::summaryFor($user->id),
        ], $metric);
    }

    public function sellers(Request $request): JsonResponse
    {
        $this->requirePremium($request);

        $rows = Transaction::query()
            ->select('seller_id', DB::raw('SUM(amount) as total_amount'), DB::raw('COUNT(*) as sales_count'))
            ->where('payment_status', 'completed')
            ->whereYear('completed_at', now()->year)
            ->whereMonth('completed_at', now()->month)
            ->whereHas('seller', fn ($q) => $q->where('is_premium', true)->where('ranking_opt_in', true))
            ->groupBy('seller_id')
            ->orderByDesc('total_amount')
            ->limit(self::LIMIT)
            ->with('seller')
            ->get();

        $ranking = $rows->values()->map(fn ($row, $i) => $this->presentUser($row->seller, $i + 1, [
            'total_amount' => (float) $row->total_amount,
            'sales_count' => (int) $row->sales_count,
        ]));

        return response()->json(['month' => now()->format('Y-m'), 'ranking' => $ranking]);
    }

    public function buyers(Request $request): JsonResponse
    {
        $this->requirePremium($request);

        $rows = Transaction::query()
            ->select('buyer_id', DB::raw('SUM(amount) as total_amount'), DB::raw('COUNT(*) as purchases_count'))
            ->where('payment_status', 'completed')
            ->whereYear('completed_at', now()->year)
            ->whereMonth('completed_at', now()->month)
            ->whereHas('buyer', fn ($q) => $q->where('is_premium', true)->where('ranking_opt_in', true))
            ->groupBy('buyer_id')
            ->orderByDesc('total_amount')
            ->limit(self::LIMIT)
            ->with('buyer')
            ->get();

        $ranking = $rows->values()->map(fn ($row, $i) => $this->presentUser($row->buyer, $i + 1, [
            'total_amount' => (float) $row->total_amount,
            'purchases_count' => (int) $row->purchases_count,
        ]));

        return response()->json(['month' => now()->format('Y-m'), 'ranking' => $ranking]);
    }

    // Le produit "represente" son vendeur dans ce classement : meme regle
    // d'eligibilite (vendeur Premium + opt-in) que pour le classement vendeurs.
    public function products(Request $request): JsonResponse
    {
        $this->requirePremium($request);

        $products = Product::query()
            ->where('status', 'active')
            ->whereHas('user', fn ($q) => $q->where('is_premium', true)->where('ranking_opt_in', true))
            ->orderByDesc('view_count')
            ->limit(self::LIMIT)
            ->with(['user', 'video'])
            ->get();

        $ranking = $products->values()->map(function (Product $product, int $i) {
            $anonymous = (bool) $product->user->ranking_anonymous;

            return [
                'rank' => $i + 1,
                'product_id' => $product->id,
                'product_slug' => $product->slug,
                'product_title' => $product->title,
                // Meme ordre de repli que MarketplaceController/ProductFeedController.
                'product_image' => $product->poster_full_url
                    ?? $product->video?->thumbnail_url
                    ?? ($product->images[0] ?? null),
                'view_count' => $product->view_count,
                'anonymous' => $anonymous,
                'seller_username' => $anonymous ? null : $product->user->username,
                'seller_name' => $anonymous ? 'Vendeur anonyme' : $product->user->full_name,
            ];
        });

        return response()->json(['ranking' => $ranking]);
    }

    public function profiles(Request $request): JsonResponse
    {
        $this->requirePremium($request);

        $users = User::query()
            ->where('is_premium', true)
            ->where('ranking_opt_in', true)
            ->orderByDesc('profile_views_count')
            ->limit(self::LIMIT)
            ->get();

        $ranking = $users->values()->map(fn (User $user, int $i) => $this->presentUser($user, $i + 1, [
            'profile_views_count' => $user->profile_views_count,
        ]));

        return response()->json(['ranking' => $ranking]);
    }

    // "Postuler" aux classements — reserve aux comptes Premium. Un compte
    // gratuit ne peut pas activer opt_in (mais garder la preference
    // choisie avant expiration n'a pas d'effet tant qu'il n'est pas actif,
    // puisque toutes les requetes de classement filtrent aussi is_premium).
    public function updatePreferences(Request $request): JsonResponse
    {
        $this->requirePremium($request);

        $validated = $request->validate([
            'opt_in' => 'required|boolean',
            'anonymous' => 'sometimes|boolean',
        ]);

        $user = $request->user();
        $user->update([
            'ranking_opt_in' => $validated['opt_in'],
            'ranking_anonymous' => $validated['anonymous'] ?? $user->ranking_anonymous,
        ]);

        return response()->json([
            'ranking_opt_in' => $user->ranking_opt_in,
            'ranking_anonymous' => $user->ranking_anonymous,
        ]);
    }

    // Etat courant des preferences pour l'ecran de reglages — accessible
    // meme hors Premium, pour pouvoir afficher le message d'upsell plutot
    // qu'une erreur 403 brute a l'ouverture de l'ecran.
    public function myPreferences(Request $request): JsonResponse
    {
        $user = $request->user();

        return response()->json([
            'is_premium' => $user->isPremiumActive(),
            'ranking_opt_in' => $user->ranking_opt_in,
            'ranking_anonymous' => $user->ranking_anonymous,
        ]);
    }
}
