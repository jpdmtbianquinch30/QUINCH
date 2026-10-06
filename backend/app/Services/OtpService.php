<?php

namespace App\Services;

use App\Mail\PasswordResetCodeMail;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\RateLimiter;

class OtpService
{
    /**
     * Vérifie les limites d'envoi pour cet identifiant (e-mail) ET les compte.
     * À appeler AVANT de savoir si le compte existe : une adresse inconnue est
     * limitée exactement comme une adresse connue (pas d'énumération de comptes).
     *
     * @return int|null  null = envoi autorisé ; sinon secondes à attendre.
     */
    public function throttle(string $identifier): ?int
    {
        $id          = sha1($identifier);
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
     * Génère un nouveau code pour l'utilisateur et l'envoie PAR E-MAIL (file Redis).
     *
     * Un échec d'envoi (file indisponible...) est journalisé mais ne remonte pas :
     * la réponse de l'API doit rester identique que le compte existe ou non,
     * sinon une erreur 500 révélerait quelles adresses sont inscrites.
     *
     * @return string le code en clair (à n'exposer qu'en test : demo_otp)
     */
    public function issue(User $user): string
    {
        $otp = $user->generateOtp();

        // Le plafond global ne compte que les vrais envois.
        RateLimiter::hit('otp:global', 3600);

        try {
            Mail::to($user->email)->queue(
                new PasswordResetCodeMail($otp, (int) config('quinch.otp.ttl_minutes', 10))
            );
        } catch (\Throwable $e) {
            Log::error('Envoi du code de réinitialisation impossible.', [
                'user_id' => $user->id,
                'error'   => $e->getMessage(),
            ]);
        }

        return $otp;
    }

    /**
     * Le code peut-il être renvoyé dans la réponse API (champ demo_otp) ?
     *
     * Oui UNIQUEMENT en environnement de test. Jamais en local ni en production :
     * un code exposé dans la réponse permettrait à n'importe qui de réinitialiser
     * le mot de passe d'un compte. En développement, lire le code dans le journal
     * (MAIL_MAILER=log) ou dans l'outil de capture d'e-mails.
     */
    public function shouldExposeDemoCode(): bool
    {
        return app()->environment('testing');
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
