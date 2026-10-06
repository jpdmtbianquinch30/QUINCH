<?php

namespace App\Services\Admin;

use App\Models\SiteSetting;
use App\Models\User;
use App\Models\UserStrike;
use App\Services\NotificationService;

/**
 * Avertissements (« strikes »). N avertissements actifs => suspension automatique.
 * Seuil, durée de suspension et durée de validité d'un strike : réglages admin
 * (moderation.strike_threshold / strike_suspension_days / strike_expiry_days).
 */
class StrikeService
{
    public function __construct(
        private SanctionService $sanctions,
        private NotificationService $notif
    ) {}

    public function activeCount(User $user): int
    {
        return UserStrike::where('user_id', $user->id)->active()->count();
    }

    public function add(User $user, string $reason, ?User $by = null, ?string $productId = null, ?string $videoId = null): UserStrike
    {
        $expiryDays = (int) SiteSetting::get('moderation.strike_expiry_days', 180);

        $strike = UserStrike::create([
            'user_id'    => $user->id,
            'product_id' => $productId,
            'video_id'   => $videoId,
            'reason'     => mb_substr($reason, 0, 500),
            'issued_by'  => $by?->id,
            'expires_at' => $expiryDays > 0 ? now()->addDays($expiryDays) : null,
        ]);

        $count = $this->activeCount($user);
        $threshold = max(1, (int) SiteSetting::get('moderation.strike_threshold', 3));

        AdminLogger::log($by, 'strike_added', 'User', $user->id, [
            'reason' => $reason, 'active_strikes' => $count, 'threshold' => $threshold,
        ], 'warning');

        $shouldSuspend = $count >= $threshold
            && $user->account_status === 'active'
            && $user->role === 'user';

        if ($shouldSuspend) {
            $days = max(1, (int) SiteSetting::get('moderation.strike_suspension_days', 7));
            $this->sanctions->suspend(
                $user,
                "{$count} avertissements actifs. Dernier motif : {$reason}",
                $days,
                null,
                true
            );
        } else {
            $this->notif->notifyAdmin(
                $user->id,
                "Avertissement {$count}/{$threshold}",
                "Votre compte a reçu un avertissement. Motif : {$reason}. À {$threshold} avertissements, votre compte sera suspendu.",
                null,
                ['kind' => 'warning', 'concerned_admin_id' => $by?->id, 'contest' => ['target_type' => 'strike', 'target_id' => $strike->id]]
            );
        }

        return $strike;
    }

    /** Retire les avertissements liés à une vidéo (appel accepté, vidéo rétablie). */
    public function revokeForVideo(string $videoId): void
    {
        UserStrike::where('video_id', $videoId)->whereNull('revoked_at')->update(['revoked_at' => now()]);
    }
}
