<?php

namespace App\Support;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Queue;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\Storage;
use Throwable;

/**
 * État de santé de l'application (utilisé par GET /api/v1/ops/health et quinch:health).
 *
 * Chaque contrôle renvoie « ok », « degraded » (à surveiller) ou « down » (panne).
 * Seule la base de données est CRITIQUE : si elle est « down », l'API répond 503.
 */
final class HealthChecker
{
    public const SCHEDULER_KEY = 'health:scheduler_heartbeat';

    /** @return array{status: string, critical: bool, checks: array<string, array<string, mixed>>} */
    public function run(bool $deep = false): array
    {
        $checks = [
            'database'  => $this->database(),
            'cache'     => $this->cache(),
            'queue'     => $this->queue(),
            'scheduler' => $this->scheduler(),
            'disk'      => $this->disk(),
        ];

        if ($deep) {
            $checks['media'] = $this->media();
        }

        $critical = ($checks['database']['status'] ?? 'down') === 'down';
        $statuses = array_column($checks, 'status');

        $status = match (true) {
            $critical => 'down',
            in_array('down', $statuses, true), in_array('degraded', $statuses, true) => 'degraded',
            default => 'ok',
        };

        return ['status' => $status, 'critical' => $critical, 'checks' => $checks];
    }

    /** @return array<string, mixed> */
    private function database(): array
    {
        try {
            $start = microtime(true);
            DB::select('select 1');
            $ms = (int) round((microtime(true) - $start) * 1000);

            return ['status' => $ms > 500 ? 'degraded' : 'ok', 'latency_ms' => $ms];
        } catch (Throwable) {
            return ['status' => 'down'];
        }
    }

    /** @return array<string, mixed> */
    private function cache(): array
    {
        try {
            Cache::put('health:ping', '1', 30);

            return ['status' => Cache::get('health:ping') === '1' ? 'ok' : 'degraded'];
        } catch (Throwable) {
            return ['status' => 'down'];
        }
    }

    /** @return array<string, mixed> */
    private function queue(): array
    {
        try {
            $result = ['status' => 'ok'];

            // Taille des files : seulement quand elles sont dans Redis (la file « sync » n'a pas de retard).
            if (config('queue.default') === 'redis') {
                $sizes = [];
                foreach (['default', (string) config('quinch.video.queue', 'videos')] as $name) {
                    $sizes[$name] = (int) Queue::size($name);
                }
                $result['sizes'] = $sizes;

                if (max($sizes) > (int) config('ops.queue_alert_size', 1000)) {
                    $result['status'] = 'degraded';
                }
            }

            // Tâches en échec sur la dernière heure.
            if (Schema::hasTable('failed_jobs')) {
                $failed = DB::table('failed_jobs')->where('failed_at', '>=', now()->subHour())->count();
                $result['failed_last_hour'] = $failed;

                if ($failed > 0) {
                    $result['status'] = 'degraded';
                }
            }

            return $result;
        } catch (Throwable) {
            return ['status' => 'down'];
        }
    }

    /** @return array<string, mixed> */
    private function scheduler(): array
    {
        try {
            $last = Cache::get(self::SCHEDULER_KEY);

            if (!$last) {
                return ['status' => 'degraded', 'detail' => 'aucun battement enregistré'];
            }

            $age = now()->timestamp - (int) $last;

            return ['status' => $age > 300 ? 'degraded' : 'ok', 'seconds_since_last_run' => $age];
        } catch (Throwable) {
            return ['status' => 'down'];
        }
    }

    /** @return array<string, mixed> */
    private function disk(): array
    {
        $path  = storage_path();
        $free  = @disk_free_space($path);
        $total = @disk_total_space($path);

        if ($free === false || $total === false || $total <= 0) {
            return ['status' => 'degraded', 'detail' => 'espace disque illisible'];
        }

        $freePercent = (int) round($free / $total * 100);

        return [
            'status'       => $freePercent < (int) config('ops.disk_min_free_percent', 15) ? 'degraded' : 'ok',
            'free_percent' => $freePercent,
        ];
    }

    /** Écrit, relit et supprime un petit fichier sur le disque des médias. @return array<string, mixed> */
    private function media(): array
    {
        try {
            $disk = Storage::disk('public');
            $key  = 'health/' . bin2hex(random_bytes(6)) . '.txt';

            $disk->put($key, 'ok');
            $read = $disk->get($key);
            $disk->delete($key);

            return ['status' => $read === 'ok' ? 'ok' : 'degraded', 'driver' => config('filesystems.disks.public.driver')];
        } catch (Throwable) {
            return ['status' => 'down', 'driver' => config('filesystems.disks.public.driver')];
        }
    }
}
