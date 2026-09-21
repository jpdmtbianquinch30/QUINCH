<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\NotificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

class GoogleAuthController extends Controller
{
    /**
     * Authenticate with Google ID token (from Flutter google_sign_in).
     * Flutter sends the idToken directly — no redirect needed.
     */
    public function handleToken(Request $request): JsonResponse
    {
        $request->validate([
            'id_token' => ['required', 'string'],
        ]);

        // Verify the Google ID token
        $googleUser = $this->verifyGoogleToken($request->id_token);

        if (!$googleUser) {
            return response()->json([
                'message' => 'Token Google invalide.',
                'error' => 'invalid_token',
            ], 401);
        }

        $googleId    = $googleUser['sub'];
        $email       = $googleUser['email'] ?? null;
        $fullName    = $googleUser['name'] ?? 'Utilisateur QUINCH';
        $avatar      = $googleUser['picture'] ?? null;

        // Rattachement du compte :
        //  - par `google_id` : toujours sûr, c'est notre propre lien.
        //  - par e-mail : UNIQUEMENT si Google confirme que l'e-mail est
        //    vérifié. Sans ce contrôle, il suffisait de créer un compte
        //    Google Workspace portant l'e-mail d'une victime pour récupérer
        //    son compte QUINCH (et donc ses transactions et son solde).
        $emailVerified = filter_var($googleUser['email_verified'] ?? false, FILTER_VALIDATE_BOOLEAN);

        $user = User::where('google_id', $googleId)->first();

        if (!$user && $email && $emailVerified) {
            $user = User::where('email', $email)->first();
        }

        if (!$user && $email && !$emailVerified) {
            return response()->json([
                'message' => "L'adresse e-mail de ce compte Google n'est pas vérifiée.",
                'error'   => 'email_not_verified',
            ], 422);
        }

        $isNewUser = false;

        if (!$user) {
            // New user — create account. `google_id` est volontairement
            // hors de $fillable (champ d'identité lié à l'auth, jamais
            // assignable via une requête externe) : forceFill nécessaire.
            $isNewUser = true;
            $username  = $this->generateUsername($fullName, $email);

            $user = User::create([
                'email'        => $email,
                'full_name'    => $fullName,
                'username'     => $username,
                'avatar_url'   => $avatar,
                'password'     => bcrypt(Str::random(32)), // random unusable password
                'is_seller'    => true,
                'is_buyer'     => true,
                'phone_verified' => false,
            ]);
            $user->forceFill(['google_id' => $googleId])->save();

            app(NotificationService::class)->notifyWelcome($user);
        } else {
            // Existing user — update google_id and avatar if needed
            $updates = [];
            if (!$user->google_id) $updates['google_id'] = $googleId;
            if (!$user->avatar_url && $avatar) $updates['avatar_url'] = $avatar;
            if (!empty($updates)) $user->forceFill($updates)->save();
        }

        // Revoke old tokens & create new one
        $user->tokens()->delete();
        $token = $user->createToken('quinch-app')->plainTextToken;

        return response()->json([
            'message'        => $isNewUser ? 'Compte créé avec Google.' : 'Connexion réussie.',
            'user'           => $this->formatUser($user),
            'token'          => $token,
            'is_new_user'    => $isNewUser,
            'needs_phone'    => !$user->phone_number,
            'needs_username' => !$user->username || str_starts_with($user->username, 'user_'),
        ]);
    }

    /**
     * Add or update phone number after Google login.
     */
    public function addPhone(Request $request): JsonResponse
    {
        $user = $request->user();

        $validated = $request->validate([
            'phone_number' => ['required', 'string', 'regex:/^\+221[0-9]{9}$/', 'unique:users,phone_number,' . $user->id],
        ], [
            'phone_number.regex'  => 'Le numéro doit être au format Sénégal (+221XXXXXXXXX).',
            'phone_number.unique' => 'Ce numéro est déjà utilisé par un autre compte.',
        ]);

        $user->update([
            'phone_number' => $validated['phone_number'],
        ]);

        // Generate OTP for phone verification
        $otp = $user->generateOtp();

        $response = [
            'message'  => 'Numéro ajouté. Vérifiez votre téléphone.',
            'user'     => $this->formatUser($user),
            'otp_sent' => true,
        ];

        if (app()->environment(['local', 'testing'])) {
            $response['demo_otp'] = $otp;
        }

        return response()->json($response);
    }

    /**
     * Update username after Google login.
     */
    public function updateUsername(Request $request): JsonResponse
    {
        $user = $request->user();

        $validated = $request->validate([
            'username' => ['required', 'string', 'min:3', 'max:30', 'unique:users,username,' . $user->id, 'regex:/^[a-zA-Z0-9_]+$/'],
        ], [
            'username.unique' => "Ce nom d'utilisateur est déjà pris.",
            'username.regex'  => "Lettres, chiffres et _ uniquement.",
        ]);

        $user->update(['username' => $validated['username']]);

        return response()->json([
            'message' => "Nom d'utilisateur mis à jour.",
            'user'    => $this->formatUser($user),
        ]);
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────

    /**
     * Vérifie un ID token Google.
     *
     * Contrôles appliqués (tous obligatoires — l'absence de l'un d'eux rend
     * la vérification inutile) :
     *  - `aud`  : le token a bien été émis POUR notre application ;
     *  - `iss`  : il a bien été émis PAR Google ;
     *  - `exp`  : il n'est pas expiré ;
     *  - `sub`  : l'identifiant stable de l'utilisateur est présent.
     *
     * `email_verified` n'est volontairement PAS filtré ici : il est remonté
     * tel quel et exploité par l'appelant, qui refuse le rattachement à un
     * compte existant si l'e-mail n'est pas vérifié par Google (voir
     * handleToken) — sans quoi un compte Google créé avec l'e-mail d'une
     * victime permettrait la prise de contrôle de son compte QUINCH.
     */
    private function verifyGoogleToken(string $idToken): ?array
    {
        try {
            $response = Http::timeout(10)->get('https://oauth2.googleapis.com/tokeninfo', [
                'id_token' => $idToken,
            ]);

            if (!$response->successful()) {
                return null;
            }

            $payload = $response->json();

            // 1. Audience : le token doit avoir été émis pour l'un de nos clients.
            $validAudiences = array_filter([
                config('services.google.client_id'),
                config('services.google.android_client_id'),
                config('services.google.ios_client_id'),
            ]);

            if (empty($validAudiences)) {
                Log::error('Google auth: aucun client_id configuré, vérification impossible.');
                return null;
            }

            if (!in_array($payload['aud'] ?? '', $validAudiences, true)) {
                return null;
            }

            // 2. Émetteur : Google, et personne d'autre.
            if (!in_array($payload['iss'] ?? '', ['accounts.google.com', 'https://accounts.google.com'], true)) {
                return null;
            }

            // 3. Expiration.
            if (!isset($payload['exp']) || (int) $payload['exp'] < time()) {
                return null;
            }

            // 4. Identifiant stable obligatoire.
            if (empty($payload['sub'])) {
                return null;
            }

            return $payload;
        } catch (\Throwable $e) {
            Log::warning('Google auth: échec de vérification du token.', ['exception' => $e->getMessage()]);
            return null;
        }
    }

    private function generateUsername(string $fullName, ?string $email): string
    {
        // Try from full name first
        $base = Str::slug(explode(' ', $fullName)[0], '_');
        $base = preg_replace('/[^a-zA-Z0-9_]/', '', $base);
        $base = substr($base ?: 'user', 0, 20);

        $username = $base;
        $counter  = 1;

        while (User::where('username', $username)->exists()) {
            $username = $base . '_' . $counter++;
        }

        return $username;
    }

    private function formatUser(User $user): array
    {
        return [
            'id'                   => $user->id,
            'phone_number'         => $user->phone_number,
            'email'                => $user->email,
            'username'             => $user->username,
            'full_name'            => $user->full_name,
            'avatar_url'           => $user->avatar_url,
            'cover_url'            => $user->cover_url,
            'bio'                  => $user->bio,
            'trust_score'          => $user->trust_score,
            'trust_level'          => $user->trust_level,
            'trust_badge'          => $user->trust_badge,
            'kyc_status'           => $user->kyc_status,
            'city'                 => $user->city,
            'region'               => $user->region,
            'role'                 => $user->role,
            'is_seller'            => $user->is_seller,
            'is_buyer'             => $user->is_buyer,
            'phone_verified'       => $user->phone_verified,
            'onboarding_completed' => $user->onboarding_completed,
            'preferences'          => $user->preferences,
            'google_id'            => $user->google_id,
            'has_password'         => !empty($user->password),
            'created_at'           => $user->created_at,
        ];
    }
}