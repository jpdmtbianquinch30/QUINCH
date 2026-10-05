<?php

namespace App\Jobs;

use App\Http\Controllers\Api\V1\AdminSettingsController;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * Envoi de masse (annonce admin) : insertion par paquets de 500, hors requête HTTP.
 * Insertion directe dans user_notifications (pas de regroupement, pas de lecture
 * des préférences ligne par ligne = rapide).
 */
class BroadcastNotificationJob implements ShouldQueue
{
    use Dispatchable, Queueable;

    public int $timeout = 600;

    public function __construct(
        public string $title,
        public string $body,
        public string $audience,
        public ?string $city,
        public ?string $actionUrl
    ) {}

    public function handle(): void
    {
        AdminSettingsController::audienceQuery($this->audience, $this->city)
            ->select('id')
            ->chunkById(500, function ($users) {
                $now = now();
                $rows = [];
                foreach ($users as $u) {
                    $rows[] = [
                        'id' => (string) Str::uuid(),
                        'user_id' => $u->id,
                        'type' => 'admin',
                        'title' => $this->title,
                        'body' => $this->body,
                        'icon' => 'campaign',
                        'action_url' => $this->actionUrl ?? '/guide/index.html',
                        'priority' => 'critical',
                        'group_count' => 1,
                        'is_read' => false,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ];
                }
                DB::table('user_notifications')->insert($rows);
            });
    }
}
