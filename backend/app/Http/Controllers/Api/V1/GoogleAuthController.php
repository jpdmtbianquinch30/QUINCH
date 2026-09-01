<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\NotificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
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

        // Check if user already exists with this Google ID or email
        $user = User::where('google_id', $googleId)->first()
            ?? ($email ? User::where('email', $email)->first() : null);

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

    private function verifyGoogleToken(string $idToken): ?array
    {
        try {
            $response = Http::get('https://oauth2.googleapis.com/tokeninfo', [
                'id_token' => $idToken,
            ]);

            if (!$response->successful()) return null;

            $payload = $response->json();

            // Verify audience matches our client ID
            $validAudiences = [
                config('services.google.client_id'),
                env('GOOGLE_ANDROID_CLIENT_ID'),
            ];

            if (!in_array($payload['aud'] ?? '', array_filter($validAudiences))) {
                return null;
            }

            return $payload;
        } catch (\Exception $e) {
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