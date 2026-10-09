<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\NotificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    /**
     * Inscription par e-mail. Le numéro de téléphone n'est plus demandé : il
     * devient une information facultative du profil.
     */
    public function register(Request $request): JsonResponse
    {
        $request->merge(['email' => strtolower(trim((string) $request->input('email')))]);

        $validated = $request->validate([
            'email'     => ['required', 'string', 'email', 'max:255', 'unique:users,email'],
            'full_name' => ['required', 'string', 'max:100'],
            'username'  => ['required', 'string', new \App\Rules\AvailableUsername()],
            'password'  => ['required', 'string', 'min:8', 'max:72', 'confirmed', 'regex:/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).+$/'],
            'accept_terms' => ['accepted'],
        ], [
            'email.email'    => 'Adresse e-mail invalide.',
            'email.unique'   => 'Cette adresse e-mail est déjà utilisée.',
            'username.unique' => "Ce nom d'utilisateur est déjà pris.",
            'username.regex'  => 'Lettres, chiffres et _ uniquement.',
            'password.regex'  => 'Le mot de passe doit contenir au moins une majuscule, une minuscule et un chiffre.',
            'password.min'    => 'Le mot de passe doit faire au moins 8 caractères.',
            'accept_terms.accepted' => "Vous devez accepter les conditions d'utilisation et la politique de confidentialité.",
        ]);

        $user = User::create([
            'email' => $validated['email'],
            'full_name' => $validated['full_name'],
            'password' => $validated['password'],
            'username' => $validated['username'],
            'is_seller' => true,
            'is_buyer' => true,
            'device_fingerprint' => ($request->header('X-Device-Fingerprint') ? mb_substr((string) $request->header('X-Device-Fingerprint'), 0, 255) : null),
        ]);
        $user->recordLegalConsent();

        // Message de bienvenue de l'équipe QUINCH dès l'inscription (et non à la 1re connexion).
        app(NotificationService::class)->notifyWelcome($user);

        $token = $user->createToken('quinch-app')->plainTextToken;

        return response()->json([
            'message' => 'Inscription réussie.',
            'user' => $this->formatUser($user),
            'token' => $token,
        ], 201);
    }

    /**
     * Connexion par e-mail et mot de passe.
     */
    public function login(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'email'    => ['required', 'string', 'email'],
            'password' => ['required', 'string'],
        ]);

        $email = strtolower(trim($validated['email']));

        // Deux compteurs : strict par (e-mail + IP), large par e-mail seul
        // (attaque répartie sur plusieurs IP). Un e-mail inconnu est compté
        // exactement pareil : aucune énumération de comptes possible.
        $pairKey  = 'login:pair:' . sha1($email . '|' . $request->ip());
        $phoneKey = 'login:email:' . sha1($email);

        foreach ([[$pairKey, 5], [$phoneKey, 20]] as [$key, $max]) {
            if (\Illuminate\Support\Facades\RateLimiter::tooManyAttempts($key, $max)) {
                $minutes = (int) ceil(\Illuminate\Support\Facades\RateLimiter::availableIn($key) / 60);

                throw ValidationException::withMessages([
                    'email' => ["Trop de tentatives. Réessayez dans {$minutes} minute(s)."],
                ])->status(429);
            }
        }

        $user = User::where('email', $email)->first();

        if ($user) {
            $passwordOk = Hash::check($validated['password'], $user->password);
        } else {
            // Même durée de calcul qu'un vrai compte : on ne révèle pas
            // l'existence d'un e-mail par le temps de réponse.
            Hash::make($validated['password']);
            $passwordOk = false;
        }

        if (!$passwordOk) {
            \Illuminate\Support\Facades\RateLimiter::hit($pairKey, 900);
            \Illuminate\Support\Facades\RateLimiter::hit($phoneKey, 3600);

            throw ValidationException::withMessages([
                'email' => ['Les identifiants sont incorrects.'],
            ]);
        }

        \Illuminate\Support\Facades\RateLimiter::clear($pairKey);

        if ($user->isBanned()) {
            return response()->json([
                'message' => 'Votre compte a été banni.' . ($user->ban_reason ? ' Raison : ' . $user->ban_reason : ''),
                'error' => 'account_banned',
            ], 403);
        }

        if ($user->isSuspended()) {
            return response()->json([
                'message' => 'Votre compte est suspendu.',
                'error' => 'account_suspended',
            ], 403);
        }

        // Update device fingerprint
        $user->update([
            'device_fingerprint' => ($request->header('X-Device-Fingerprint') ? mb_substr((string) $request->header('X-Device-Fingerprint'), 0, 255) : null),
        ]);

        // Revoke old tokens & create new one
        $user->tokens()->delete();
        // Le staff (modérateur / admin / super admin) reçoit un jeton de durée courte.
        $token = $user->createToken(
            'quinch-app',
            ['*'],
            $user->isStaff() ? now()->addHours((int) config('quinch.staff_token_hours', 8)) : null
        )->plainTextToken;

        // Welcome notification on first login (no previous tokens = first time)
        app(NotificationService::class)->notifyWelcome($user);

        return response()->json([
            'message' => 'Connexion réussie.',
            'user' => $this->formatUser($user),
            'token' => $token,
        ]);
    }

    /**
     * Demande de réinitialisation de mot de passe : un code à 6 chiffres est
     * envoyé PAR E-MAIL. Ne révèle jamais si l'adresse existe (même réponse
     * dans les deux cas) pour ne pas permettre d'énumérer les comptes.
     */
    public function forgotPassword(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'email' => ['required', 'string', 'email', 'max:255'],
        ]);

        $email = strtolower(trim($validated['email']));

        $otpService = app(\App\Services\OtpService::class);

        $wait = $otpService->throttle($email);
        if ($wait !== null) {
            return $otpService->tooManyResponse($wait);
        }

        $user = User::where('email', $email)->first();

        $response = [
            'message' => 'Si cette adresse est associée à un compte, un code a été envoyé par e-mail.',
        ];

        if ($user) {
            $otp = $otpService->issue($user);

            if ($otpService->shouldExposeDemoCode()) {
                $response['demo_otp'] = $otp;
            }
        }

        return response()->json($response);
    }

    /**
     * Réinitialise le mot de passe après vérification du code reçu par e-mail.
     * Révoque tous les jetons existants (déconnexion de tous les appareils),
     * au cas où le compte aurait été compromis.
     */
    public function resetPassword(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'email' => ['required', 'string', 'email'],
            'otp' => ['required', 'string', 'size:6'],
            'password' => ['required', 'confirmed', 'min:8', 'max:72', 'regex:/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).+$/'],
        ], [
            'password.regex' => 'Le mot de passe doit contenir au moins une majuscule, une minuscule et un chiffre.',
        ]);

        $user = User::where('email', strtolower(trim($validated['email'])))->first();

        if (!$user || !$user->verifyOtp($validated['otp'])) {
            return response()->json([
                'message' => 'Code invalide ou expiré.',
                'error' => 'invalid_otp',
            ], 422);
        }

        // otp_code/otp_expires_at ne sont pas fillable : forceFill nécessaire.
        // Avoir reçu le code prouve la possession de l'adresse : on la marque vérifiée.
        $user->forceFill([
            'password' => $validated['password'],
            'otp_code' => null,
            'otp_expires_at' => null,
            'email_verified_at' => $user->email_verified_at ?? now(),
        ])->save();

        // Un mot de passe oublié/réinitialisé peut indiquer un compte compromis.
        $user->tokens()->delete();

        return response()->json([
            'message' => 'Mot de passe réinitialisé avec succès. Merci de vous reconnecter.',
        ]);
    }

    /**
     * Get authenticated user.
     */
    public function me(Request $request): JsonResponse
    {
        return response()->json([
            'user' => $this->formatUser($request->user()),
        ]);
    }

    /**
     * Logout (revoke current token).
     */
    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json([
            'message' => 'Déconnexion réussie.',
        ]);
    }

    /**
     * Logout from all devices.
     */
    public function logoutAll(Request $request): JsonResponse
    {
        $request->user()->tokens()->delete();

        return response()->json([
            'message' => 'Déconnexion de tous les appareils réussie.',
        ]);
    }

    /**
     * Refresh token.
     */
    public function refresh(Request $request): JsonResponse
    {
        $user = $request->user();
        $user->currentAccessToken()->delete();
        $token = $user->createToken(
            'quinch-app',
            ['*'],
            $user->isStaff() ? now()->addHours((int) config('quinch.staff_token_hours', 8)) : null
        )->plainTextToken;

        return response()->json([
            'token' => $token,
            'user' => $this->formatUser($user),
        ]);
    }

    public function changePassword(Request $request): JsonResponse
    {
        $request->validate([
            'current_password' => ['required', 'string'],
            'new_password' => ['required', 'string', 'min:8', 'max:72', 'confirmed', 'regex:/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).+$/'],
        ], [
            'new_password.regex' => 'Le mot de passe doit contenir au moins une majuscule, une minuscule et un chiffre.',
        ]);

        $user = $request->user();

        if (!Hash::check($request->current_password, $user->password)) {
            return response()->json(['message' => 'Le mot de passe actuel est incorrect.'], 422);
        }

        $user->update([
            'password' => Hash::make($request->new_password),
        ]);

        // Un jeton volé ne doit pas survivre au changement de mot de passe.
        $user->revokeOtherTokens();

        return response()->json(['message' => 'Mot de passe modifié avec succès.']);
    }

    /**
     * Suppression de SON compte : le mot de passe est exigé (un jeton volé ne
     * suffit pas). Le compte est ANONYMISÉ (données personnelles effacées, lignes
     * de transactions / signalements conservées pour les litiges et obligations
     * légales) — un DELETE réel échouerait dès la première transaction.
     * Les comptes de l'équipe ne se suppriment pas ici.
     */
    public function deleteAccount(Request $request): JsonResponse
    {
        $validated = $request->validate(['password' => ['required', 'string']]);
        $user = $request->user();

        if ($user->isStaff()) {
            return response()->json([
                'message' => "Un compte de l'équipe ne peut pas être supprimé ici. Contactez un super administrateur.",
                'error' => 'staff_cannot_self_delete',
            ], 403);
        }

        if (!Hash::check($validated['password'], $user->password)) {
            throw ValidationException::withMessages(['password' => ['Mot de passe incorrect.']]);
        }

        app(\App\Services\Admin\SanctionService::class)->anonymize($user, "Suppression à la demande de l'utilisateur", null);

        return response()->json(['message' => 'Compte supprimé avec succès.']);
    }

    private function formatUser(User $user): array
    {
        return [
            'id' => $user->id,
            'phone_number' => $user->phone_number,
            'email' => $user->email,
            'username' => $user->username,
            'full_name' => $user->full_name,
            'avatar_url' => $user->avatar_url,
            'cover_url' => $user->cover_url,
            'bio' => $user->bio,
            'website' => $user->website,
            'seller_policies' => $user->seller_policies,
            'trust_score' => $user->trust_score,
            'trust_level' => $user->trust_level,
            'trust_badge' => $user->trust_badge,
            'kyc_status' => $user->kyc_status,
            'city' => $user->city,
            'region' => $user->region,
            'role' => $user->role, // 'user' = client, 'admin'/'super_admin' = admin
            'is_seller' => $user->is_seller,
            'is_buyer' => $user->is_buyer,
            'phone_verified' => $user->phone_verified,
            'email_verified' => $user->email_verified_at !== null,
            'onboarding_completed' => $user->onboarding_completed,
            'preferences' => $user->preferences,
            'created_at' => $user->created_at,
            // Sans ces 3 champs, AuthService.user() (le signal partagé par
            // tout le front - sidebar, profil, badge Premium) ne connaissait
            // jamais le statut premium : le badge doré ajouté dans
            // profile.component.html ne pouvait donc jamais s'afficher,
            // même pour un compte réellement premium en base.
            'is_premium' => $user->isPremiumActive(),
            'premium_plan' => $user->premium_plan,
            'premium_expires_at' => $user->premium_expires_at,
        ];
    }
}
