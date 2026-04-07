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
     * Register a new user with phone number (Senegal format).
     */
    public function register(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'phone_number' => ['required', 'string', 'regex:/^\+221[0-9]{9}$/', 'unique:users'],
            'full_name' => ['required', 'string', 'max:100'],
            'password' => ['required', 'string', 'min:6', 'confirmed'],
        ], [
            'phone_number.regex' => 'Le numéro doit être au format Sénégal (+221XXXXXXXXX).',
            'phone_number.unique' => 'Ce numéro est déjà utilisé.',
        ]);

        $user = User::create([
            'phone_number' => $validated['phone_number'],
            'full_name' => $validated['full_name'],
            'password' => $validated['password'],
            'role' => 'user',
            'is_seller' => true,
            'is_buyer' => true,
            'device_fingerprint' => $request->header('X-Device-Fingerprint'),
        ]);

        // Generate OTP for phone verification
        $otp = $user->generateOtp();

        $token = $user->createToken('quinch-app')->plainTextToken;

        return response()->json([
            'message' => 'Inscription réussie. Vérifiez votre téléphone.',
            'user' => $this->formatUser($user),
            'token' => $token,
            'otp_sent' => true,
            // In production, OTP would be sent via SMS. For demo:
            'demo_otp' => $otp,
        ], 201);
    }

    /**
     * Login with phone number and password.
     */
    public function login(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'phone_number' => ['required', 'string'],
            'password' => ['required', 'string'],
        ]);

        $user = User::where('phone_number', $validated['phone_number'])->first();

        if (!$user || !Hash::check($validated['password'], $user->password)) {
            throw ValidationException::withMessages([
                'phone_number' => ['Les identifiants sont incorrects.'],
            ]);
        }

        if ($user->isSuspended()) {
            return response()->json([
                'message' => 'Votre compte est suspendu.',
                'error' => 'account_suspended',
            ], 403);
        }

        // Update device fingerprint
        $user->update([
            'device_fingerprint' => $request->header('X-Device-Fingerprint'),
        ]);

        // Revoke old tokens & create new one
        $user->tokens()->delete();
        $token = $user->createToken('quinch-app')->plainTextToken;

        // Welcome notification on first login (no previous tokens = first time)
        app(NotificationService::class)->notifyWelcome($user);

        return response()->json([
            'message' => 'Connexion réussie.',
            'user' => $this->formatUser($user),
            'token' => $token,
        ]);
    }

    /**
     * Verify OTP code.
     */
    public function verifyOtp(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'phone_number' => ['required', 'string'],
            'otp' => ['required', 'string', 'size:6'],
        ]);

        $user = User::where('phone_number', $validated['phone_number'])->first();

        if (!$user || !$user->verifyOtp($validated['otp'])) {
            return response()->json([
                'message' => 'Code OTP invalide ou expiré.',
                'error' => 'invalid_otp',
            ], 422);
        }

        $user->update([
            'phone_verified' => true,
            'otp_code' => null,
            'otp_expires_at' => null,
        ]);

        return response()->json([
            'message' => 'Téléphone vérifié avec succès.',
            'user' => $this->formatUser($user->fresh()),
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
        $token = $user->createToken('quinch-app')->plainTextToken;

        return response()->json([
            'token' => $token,
            'user' => $this->formatUser($user),
        ]);
    }

    public function changePassword(Request $request): JsonResponse
    {
        $request->validate([
            'current_password' => ['required', 'string'],
            'new_password' => ['required', 'string', 'min:8', 'confirmed'],
        ]);

        $user = $request->user();

        if (!Hash::check($request->current_password, $user->password)) {
            return response()->json(['message' => 'Le mot de passe actuel est incorrect.'], 422);
        }

        $user->update([
            'password' => Hash::make($request->new_password),
        ]);

        return response()->json(['message' => 'Mot de passe modifié avec succès.']);
    }

    public function deleteAccount(Request $request): JsonResponse
    {
        $user = $request->user();

        // Revoke all tokens
        $user->tokens()->delete();

        // Soft delete or permanently delete
        $user->update(['status' => 'deleted']);
        $user->delete();

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
            'onboarding_completed' => $user->onboarding_completed,
            'preferences' => $user->preferences,
            'created_at' => $user->created_at,
        ];
    }
}
