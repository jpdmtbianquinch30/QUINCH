<?php

namespace App\Models\Traits;

use App\Models\AuditLog;

trait Auditable
{
    protected static function bootAuditable(): void
    {
        static::created(function ($model) {
            static::logAudit($model, 'created');
        });

        static::updated(function ($model) {
            if ($model->isDirty()) {
                static::logAudit($model, 'updated', $model->getOriginal(), $model->getAttributes());
            }
        });

        static::deleted(function ($model) {
            static::logAudit($model, 'deleted');
        });
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
            // Don't let audit logging break the app
            logger()->error('Audit logging failed: ' . $e->getMessage());
        }
    }
}
