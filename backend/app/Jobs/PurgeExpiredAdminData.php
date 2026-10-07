<?php

namespace App\Jobs;

use App\Http\Middleware\CheckBannedIp;
use App\Models\BannedIp;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Support\Facades\DB;

/**
 * Ménage quotidien : bans d'IP expirés, journaux techniques (audit_logs) de
 * plus de 180 jours. Le journal des actions d'administration (admin_action_logs)
 * n'est JAMAIS purgé : c'est la preuve des décisions de modération.
 */
class PurgeExpiredAdminData implements ShouldQueue
{
    use Dispatchable, Queueable;

    public function handle(): void
    {
        BannedIp::whereNotNull('expires_at')->where('expires_at', '<', now())->delete();
        CheckBannedIp::flush();

        // DELETE ... LIMIT n'existe pas en PostgreSQL : sous-requête sur les ids.
        DB::delete(
            'DELETE FROM audit_logs WHERE id IN (SELECT id FROM audit_logs WHERE created_at < ? LIMIT 50000)',
            [now()->subDays((int) config('legal.retention.audit_logs_days', 180))]
        );
    }
}
