<?php

namespace App\Services\Admin;

use App\Models\AdminActionLog;
use App\Models\User;

/**
 * Journal d'audit UNIQUE des actions d'administration (table admin_action_logs).
 * Toute décision de modération, sanction, changement de rôle, résolution de
 * signalement, action sur catégorie, etc. passe par ici.
 * $admin = null pour une action automatique (masquage auto, 3 strikes...).
 */
class AdminLogger
{
    public static function log(
        ?User $admin,
        string $action,
        ?string $targetType = null,
        ?string $targetId = null,
        array $metadata = [],
        string $severity = 'info'
    ): void {
        try {
            if ($admin === null) {
                $metadata['system'] = true;
            }

            AdminActionLog::create([
                'admin_id'    => $admin?->id,
                'action'      => $action,
                'target_type' => $targetType,
                'target_id'   => $targetId,
                'metadata'    => $metadata ?: null,
                'ip_address'  => request()?->ip(),
                'severity'    => $severity,
            ]);
        } catch (\Throwable $e) {
            logger()->error('Admin log failed: ' . $e->getMessage(), ['action' => $action]);
        }
    }
}
