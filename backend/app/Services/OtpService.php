<?php

namespace App\Services;

use App\Jobs\SendSmsJob;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\RateLimiter;

class OtpService
{
    /**
     * Vérifie les limites d'envoi pour ce numéro ET les compte.
     * À appeler AVANT de savoir si le compte existe : un numéro inconnu est
     * limité exactement comme un numéro connu (pas d'énumération de comptes).
     *
     * @return int|null  null = envoi autorisé ; sinon secondes à attendre.
     */
    public function throttle(string $phone): ?int
    {
        $id          = sha1($phone);
        $cooldownKey = "otp:cooldown:{$id}";
        $hourKey     = "otp:hour:{$id}";
        $globalKey   = 'otp:global';

        $checks = [
            [$cooldownKey, 1],
            [$hourKey, (int) config('quinch.otp.max_sends_per_hour', 5)],
            [$globalKey, (int) config('quinch.otp.global_sends_per_hour', 2000)],
        ];

        foreach ($checks as [$key, $max]) {
            if (RateLimiter::tooManyAttempts($key, $max)) {
                return max(1, RateLimiter::availableIn($key));
            }
        }

        RateLimiter::hit($cooldownKey, (int) config('quinch.otp.resend_cooldown_seconds', 60));
        RateLimiter::hit($hourKey, 3600);

        return null;
    }

    /**
     * Génère un nouveau code pour l'utilisateur et l'envoie par SMS.
     * $phone = numéro destinataire (par défaut le numéro du compte ; pour un
     * changement de numéro, passer le NOUVEAU numéro).
     *
     * @return string le code en clair (à n'exposer qu'en local/testing : demo_otp)
     */
    public function issue(User $user, ?string $phone = null): string
    {
        $phone ??= $user->phone_number;

        $otp = $user->generateOtp();

        // Le plafond global ne compte que les vrais envois.
        RateLimiter::hit('otp:global', 3600);

        $minutes = (int) config('quinch.otp.ttl_minutes', 10);

        SendSmsJob::dispatch(
            $phone,
            "QUINCH : votre code est {$otp}. Valable {$minutes} min. Ne le partagez avec personne."
        );

        return $otp;
    }

    public function tooManyResponse(int $retryAfter): JsonResponse
    {
        return response()->json([
            'message'     => "Trop de demandes de code. Réessayez dans {$retryAfter} seconde(s).",
            'error'       => 'otp_rate_limited',
            'retry_after' => $retryAfter,
        ], 429)->header('Retry-After', (string) $retryAfter);
    }
}
