<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Classements : 100 meilleurs vendeurs (vues + likes cumules de leurs annonces
 * actives), 100 produits les plus vus, 100 profils les plus visites.
 *
 * QUINCH ne gere pas de transactions entre utilisateurs : aucun classement
 * ne depend de ventes ou d'achats (ancien classement acheteurs supprime).
 *
 * Regle commune aux 3 : reserve aux comptes Premium, a la fois pour
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

    // Score vendeur = vues + likes cumules de ses annonces ACTIVES (les
    // annonces vendues, expirees ou desactivees ne comptent pas, sinon un
    // vendeur garderait son rang avec des produits qui n'existent plus).
    // Ex aequo departages par user_id pour un ordre stable d'un appel a l'autre.
    public function sellers(Request $request): JsonResponse
    {
        $this->requirePremium($request);

        $rows = Product::query()
            ->select(
                'user_id',
                DB::raw('SUM(view_count) as total_views'),
                DB::raw('SUM(like_count) as total_likes'),
                DB::raw('SUM(view_count + like_count) as score'),
                DB::raw('COUNT(*) as products_count')
            )
            ->where('status', 'active')
            ->whereHas('user', fn ($q) => $q->where('is_premium', true)->where('ranking_opt_in', true))
            ->groupBy('user_id')
            ->orderByDesc('score')
            ->orderBy('user_id')
            ->limit(self::LIMIT)
            ->with('user')
            ->get();

        $ranking = $rows->values()->map(fn ($row, $i) => $this->presentUser($row->user, $i + 1, [
            'score' => (int) $row->score,
            'total_views' => (int) $row->total_views,
            'total_likes' => (int) $row->total_likes,
            'products_count' => (int) $row->products_count,
        ]));

        return response()->json(['ranking' => $ranking]);
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

    // Top 100 des profils les plus suivis (nombre d'abonnés). Mêmes règles
    // d'éligibilité que les autres classements (Premium + participation).
    public function followers(Request $request): JsonResponse
    {
        $this->requirePremium($request);

        $users = User::query()
            ->where('is_premium', true)
            ->where('ranking_opt_in', true)
            ->select('users.*')
            ->selectSub(
                DB::table('user_follows')
                    ->selectRaw('COUNT(*)')
                    ->whereColumn('user_follows.following_id', 'users.id'),
                'followers_total'
            )
            ->orderByDesc('followers_total')
            ->orderBy('users.id')
            ->limit(self::LIMIT)
            ->get();

        $ranking = $users->values()->map(fn (User $user, int $i) => $this->presentUser($user, $i + 1, [
            'followers_count' => (int) $user->followers_total,
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
