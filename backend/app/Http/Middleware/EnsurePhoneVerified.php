<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Bloque l'accès aux fonctionnalités métier tant que le numéro de téléphone
 * de l'utilisateur n'est pas vérifié par OTP.
 *
 * ─── Pourquoi ce middleware a été ajouté (SEC-06) ───────────────────────────
 *
 * Cette vérification n'existait auparavant QUE côté routeur Angular (voir
 * `core/guards/auth.guard.ts`, qui redirige vers `/auth/verify-otp` si
 * `!user.phone_verified`). Un appel direct à l'API — Postman, un script,
 * une extension de navigateur, ou simplement un client mobile futur qui
 * n'implémenterait pas exactement les mêmes gardes — contournait
 * entièrement l'écran de vérification. Un compte fraîchement créé, avec un
 * numéro de téléphone jamais prouvé, pouvait ainsi publier des annonces,
 * initier un paiement ou écrire à d'autres utilisateurs.
 *
 * ─── Où il est appliqué ──────────────────────────────────────────────────
 *
 * Sur le grand groupe de routes métier de `routes/api.php` (produits,
 * panier, messagerie, favoris, notifications, transactions, premium,
 * follow, badges, reviews) — c'est-à-dire exactement les routes que
 * `authGuard` protège déjà côté Angular.
 *
 * ─── Où il est volontairement absent ────────────────────────────────────
 *
 *  - `auth/*` (logout, me, refresh, change-password...) : un utilisateur
 *    non vérifié doit pouvoir se déconnecter ou consulter son propre statut.
 *  - `auth/google/add-phone` et `auth/google/update-username` : ce sont les
 *    routes qui SERVENT à sortir de l'état "non vérifié" — les bloquer
 *    empêcherait justement de se vérifier.
 *  - le groupe `admin/*` : le rôle y est déjà contrôlé par `CheckRole`, et
 *    un compte admin n'a de toute façon aucune raison de rester non vérifié.
 *
 * (`user/phone/request-change` et `phone/confirm-change` restent, eux, à
 * l'intérieur du groupe protégé : `UserController` ne repasse jamais
 * `phone_verified` à `false` pendant un changement de numéro — seul
 * `phone_number` change une fois l'OTP confirmé — donc aucune exception
 * n'est nécessaire pour ces deux routes.)
 */
class EnsurePhoneVerified
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if ($user && !$user->phone_verified) {
            return response()->json([
                'message' => 'Vérifiez votre numéro de téléphone avant de continuer.',
                'error' => 'phone_not_verified',
            ], 403);
        }

        return $next($request);
    }
}
