<?php

namespace App\Models\Traits;

use App\Models\AuditLog;
use Illuminate\Support\Arr;

trait Auditable
{
    protected static function bootAuditable(): void
    {
        static::created(function ($model) {
            static::logAudit($model, 'created');
        });

        static::updated(function ($model) {
            // Uniquement les champs modifiés, jamais les champs secrets.
            $new = Arr::except(
                $model->getChanges(),
                array_merge(static::auditExcludedAttributes(), ['updated_at'])
            );

            if ($new === []) {
                return;
            }

            $old = Arr::only($model->getOriginal(), array_keys($new));

            static::logAudit($model, 'updated', $old, $new);
        });

        static::deleted(function ($model) {
            static::logAudit($model, 'deleted');
        });
    }

    /**
     * Champs qui ne doivent JAMAIS être écrits dans le journal d'audit.
     * Un modèle peut redéfinir cette méthode pour en ajouter.
     */
    protected static function auditExcludedAttributes(): array
    {
        return [
            'password',
            'remember_token',
            'otp_code',
            'otp_expires_at',
            'otp_attempts',
            'device_fingerprint',
        ];
    }

    protected static function logAudit($model, string $action, ?array $oldValues = null, ?array $newValues = null): void
    {
        try {
            AuditLog::create([
                'user_id' => auth()->id(),
                'action_type' => $action,
                'entity_type' => class_basename($model),
                'entity_id' => $model->getKey(),
                'ip_address' => request()->ip(),
                'user_agent' => request()->userAgent(),
                'old_values' => $oldValues,
                'new_values' => $newValues,
                'severity' => 'info',
            ]);
        } catch (\Throwable $e) {
            // Ne jamais casser l'application à cause du journal d'audit
            logger()->error('Audit logging failed: ' . $e->getMessage());
        }
    }
}
