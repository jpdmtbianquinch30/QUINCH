<?php

namespace App\Services\Admin;

use App\Models\Product;
use App\Models\User;
use App\Services\NotificationService;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * Sanctions de compte : suspension (avec date de fin), bannissement, levée,
 * anonymisation. Toutes les écritures passent ici pour rester cohérentes
 * (jetons révoqués, annonces masquées/restaurées, notification, journal).
 */
class SanctionService
{
    /** Valeur de products.moderation_reason posée quand une annonce est masquée à cause d'une sanction du compte. */
    public const ACCOUNT_SANCTION = 'account_sanction';

    public function __construct(private NotificationService $notif) {}

    public function suspend(User $user, string $reason, ?int $days = null, ?User $by = null, bool $system = false): void
    {
        $until = $days ? now()->addDays($days) : null;

        $user->forceFill([
            'account_status'    => 'suspended',
            'suspended_until'   => $until,
            'suspension_reason' => mb_substr($reason, 0, 500),
        ])->save();

        $user->tokens()->delete();
        $this->hideProducts($user);

        AdminLogger::log($by, 'user_suspended', 'User', $user->id, [
            'reason' => $reason,
            'days'   => $days,
            'until'  => $until?->toIso8601String(),
        ], 'warning');

        $this->notif->notifyAdmin(
            $user->id,
            'Compte suspendu',
            'Votre compte est suspendu' . ($until ? " jusqu'au " . $until->format('d/m/Y à H:i') : '')
                . '. Motif : ' . $reason
        );
    }

    /** Lève une suspension (manuelle ou automatique à l'échéance). Un compte banni n'est PAS concerné. */
    public function lift(User $user, string $reason, ?User $by = null): bool
    {
        if ($user->account_status !== 'suspended') {
            return false;
        }

        $user->forceFill([
            'account_status'    => 'active',
            'suspended_until'   => null,
            'suspension_reason' => null,
        ])->save();

        $this->restoreProducts($user);

        AdminLogger::log($by, 'user_reactivated', 'User', $user->id, ['reason' => $reason]);
        $this->notif->notifyAdmin($user->id, 'Compte réactivé', 'Votre compte a été réactivé.');

        return true;
    }

    public function ban(User $user, string $reason, ?User $by = null): void
    {
        $user->tokens()->delete();
        $user->forceFill([
            'account_status'    => 'banned',
            'ban_reason'        => mb_substr($reason, 0, 500),
            'banned_at'         => now(),
            'suspended_until'   => null,
            'suspension_reason' => null,
        ])->save();

        $this->hideProducts($user);

        AdminLogger::log($by, 'user_banned', 'User', $user->id, ['reason' => $reason], 'critical');
    }

    public function unban(User $user, string $reason, ?User $by = null): bool
    {
        if ($user->account_status !== 'banned') {
            return false;
        }

        $user->forceFill([
            'account_status' => 'active',
            'ban_reason'     => null,
            'banned_at'      => null,
        ])->save();

        $this->restoreProducts($user);

        AdminLogger::log($by, 'user_unbanned', 'User', $user->id, ['reason' => $reason], 'warning');
        $this->notif->notifyAdmin($user->id, 'Compte réactivé', 'Votre compte a été réactivé après réexamen.');

        return true;
    }

    /**
     * "Suppression" d'un compte par l'admin. Un DELETE réel échoue dès que le
     * compte a une transaction (clés étrangères) et détruirait les preuves.
     * On ANONYMISE : les données personnelles disparaissent, les lignes
     * (transactions, signalements, messages) restent pour les litiges.
     */
    public function anonymize(User $user, string $reason, ?User $by = null): void
    {
        DB::transaction(function () use ($user, $reason, $by) {
            $user->tokens()->delete();

            // Suppression douce de toutes ses annonces.
            Product::where('user_id', $user->id)->delete();

            $user->forceFill([
                'phone_number'         => null,
                'pending_phone_number' => null,
                'email'                => null,
                'username'             => null,
                'google_id'            => null,
                'full_name'            => 'Compte supprimé',
                'avatar_url'           => null,
                'cover_url'            => null,
                'bio'                  => null,
                'website'              => null,
                'seller_policies'      => null,
                'device_fingerprint'   => null,
                'password'             => Str::random(40), // re-hashé par le cast "hashed"
                'account_status'       => 'deactivated',
                'is_premium'           => false,
                'anonymized_at'        => now(),
            ])->save();

            AdminLogger::log($by, 'user_deleted', 'User', $user->id, ['reason' => $reason], 'critical');
        });
    }

    private function hideProducts(User $user): void
    {
        Product::where('user_id', $user->id)
            ->where('status', 'active')
            ->update([
                'status'            => 'disabled',
                'moderation_reason' => self::ACCOUNT_SANCTION,
                'moderated_at'      => now(),
            ]);
    }

    private function restoreProducts(User $user): void
    {
        Product::where('user_id', $user->id)
            ->where('status', 'disabled')
            ->where('moderation_reason', self::ACCOUNT_SANCTION)
            ->update([
                'status'            => 'active',
                'moderation_reason' => null,
            ]);
    }
}
