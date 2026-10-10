<?php

namespace App\Jobs;

use App\Models\ProductVideo;
use App\Support\MediaUrl;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\Process\Process;

/**
 * Traitement asynchrone d'une vidéo : miniature + durée.
 * Tourne sur la file dédiée "videos" pour ne jamais retarder les notifications.
 */
class ProcessVideoJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $tries = 3;

    // Doit rester < retry_after de la file (config/queue.php : 720 s).
    public int $timeout = 600;

    // Vidéo supprimée (compte effacé, modération, quinch:delete-all-videos) avant le passage
    // du worker : il n'y a plus rien à traiter, ce n'est pas une erreur -> job abandonné sans échec.
    public bool $deleteWhenMissingModels = true;

    public function __construct(public ProductVideo $video)
    {
        $this->onQueue((string) config('quinch.video.queue', 'videos'));
    }

    public function handle(): void
    {
        $disk = Storage::disk('public');

        // Fichier absent (volume de stockage réinitialisé, worker sans le volume partagé, fichier
        // purgé) : réessayer ne le fera pas réapparaître. On échoue tout de suite, une seule fois,
        // avec un message exploitable, au lieu de 3 tentatives inutiles.
        if (!$this->video->video_path || !$disk->exists($this->video->video_path)) {
            $this->fail(new \RuntimeException(sprintf(
                'Fichier vidéo introuvable (video_id=%s, chemin=%s, disque=%s). '
                . 'Vérifiez que le volume de stockage est bien partagé entre app et queue_videos.',
                $this->video->id,
                $this->video->video_path ?: '(vide)',
                config('filesystems.disks.public.driver', 'local')
            )));

            return;
        }

        $this->video->update(['processing_status' => 'processing']);

        // Stockage objet : ffprobe/ffmpeg lisent la vidéo par une URL S3 temporaire (requêtes
        // Range : seuls les octets utiles sont téléchargés, pas les 500 Mo du fichier).
        $inputPath = MediaUrl::isRemote()
            ? $disk->temporaryUrl($this->video->video_path, now()->addMinutes(30))
            : $disk->path($this->video->video_path);

        $duration  = $this->probeDuration($inputPath);
        $thumbPath = $this->generateThumbnail($inputPath, $duration);

        $this->video->update([
            'processing_status' => 'completed',
            'thumbnail_path'    => $thumbPath,
            'duration_seconds'  => $duration,
        ]);
    }

    /** Appelé quand TOUTES les tentatives ont échoué. */
    public function failed(\Throwable $e): void
    {
        Log::error('ProcessVideoJob failed', [
            'video_id' => $this->video->id,
            'error'    => $e->getMessage(),
        ]);

        // La ligne peut avoir disparu entre-temps : un UPDATE sans effet ne doit pas lever d'erreur.
        ProductVideo::whereKey($this->video->id)->update(['processing_status' => 'failed']);
    }

    private function probeDuration(string $inputPath): ?int
    {
        try {
            $process = new Process([
                'ffprobe', '-v', 'error',
                '-protocol_whitelist', 'file,https,tls,tcp,crypto',
                '-show_entries', 'format=duration',
                '-of', 'default=noprint_wrappers=1:nokey=1',
                $inputPath,
            ]);
            $process->setTimeout(60);
            $process->run();

            $out = trim($process->getOutput());
            if ($process->isSuccessful() && is_numeric($out)) {
                return (int) round((float) $out);
            }
        } catch (\Throwable $e) {
            Log::warning('ffprobe indisponible ou en échec', ['error' => $e->getMessage()]);
        }

        return null;
    }

    /** Miniature à ~1 s (0 s si vidéo < 2 s). Un échec ne rend pas la vidéo invalide. */
    private function generateThumbnail(string $inputPath, ?int $duration): ?string
    {
        $disk     = Storage::disk('public');
        $remote   = MediaUrl::isRemote();
        $thumbDir = 'thumbnails/' . date('Y/m');

        $thumbPath = $thumbDir . '/' . pathinfo($this->video->video_path, PATHINFO_FILENAME) . '.jpg';
        $seek      = ($duration !== null && $duration < 2) ? '0' : '1';

        // Disque local : ffmpeg écrit directement dans le dossier des médias.
        // Stockage objet : il écrit dans un fichier temporaire, ensuite envoyé au bucket.
        $tmpBase = null;
        if ($remote) {
            // tempnam crée un fichier vide ; ffmpeg a besoin d'une extension pour choisir le format.
            $tmpBase       = tempnam(sys_get_temp_dir(), 'qthumb_');
            $thumbFullPath = $tmpBase . '.jpg';
        } else {
            $disk->makeDirectory($thumbDir);
            $thumbFullPath = $disk->path($thumbPath);
        }

        try {
            $process = new Process([
                'ffmpeg', '-y',
                // Seuls fichier local et HTTPS (URL temporaire du bucket) : jamais concat:/file:/rtmp: forgés.
                '-protocol_whitelist', 'file,https,tls,tcp,crypto',
                '-ss', $seek,
                '-i', $inputPath,
                '-vframes', '1', '-q:v', '2',
                $thumbFullPath,
            ]);
            $process->setTimeout(120);
            $process->run();

            if ($process->isSuccessful() && file_exists($thumbFullPath)) {
                if (!$remote) {
                    return $thumbPath;
                }

                $stream = fopen($thumbFullPath, 'rb');
                try {
                    $disk->writeStream($thumbPath, $stream);
                } finally {
                    if (is_resource($stream)) {
                        fclose($stream);
                    }
                }

                return $thumbPath;
            }
        } catch (\Throwable $e) {
            Log::warning('ffmpeg indisponible ou en échec', ['error' => $e->getMessage()]);
        } finally {
            if ($remote) {
                foreach ([$thumbFullPath, $tmpBase] as $temporary) {
                    if (is_string($temporary) && file_exists($temporary)) {
                        @unlink($temporary);
                    }
                }
            }
        }

        return null;
    }
}
