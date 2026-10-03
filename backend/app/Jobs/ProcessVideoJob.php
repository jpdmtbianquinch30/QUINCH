<?php

namespace App\Jobs;

use App\Models\ProductVideo;
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

    public function __construct(public ProductVideo $video)
    {
        $this->onQueue((string) config('quinch.video.queue', 'videos'));
    }

    public function handle(): void
    {
        $this->video->update(['processing_status' => 'processing']);

        $disk = Storage::disk('public');

        if (!$this->video->video_path || !$disk->exists($this->video->video_path)) {
            throw new \RuntimeException("Fichier vidéo introuvable : {$this->video->video_path}");
        }

        $inputPath = $disk->path($this->video->video_path);

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

        $this->video->update(['processing_status' => 'failed']);
    }

    private function probeDuration(string $inputPath): ?int
    {
        try {
            $process = new Process([
                'ffprobe', '-v', 'error',
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
        $thumbDir = 'thumbnails/' . date('Y/m');
        $disk->makeDirectory($thumbDir);

        $thumbPath     = $thumbDir . '/' . pathinfo($this->video->video_path, PATHINFO_FILENAME) . '.jpg';
        $thumbFullPath = $disk->path($thumbPath);
        $seek          = ($duration !== null && $duration < 2) ? '0' : '1';

        try {
            $process = new Process([
                'ffmpeg', '-y', '-ss', $seek,
                '-i', $inputPath,
                '-vframes', '1', '-q:v', '2',
                $thumbFullPath,
            ]);
            $process->setTimeout(120);
            $process->run();

            if ($process->isSuccessful() && file_exists($thumbFullPath)) {
                return $thumbPath;
            }
        } catch (\Throwable $e) {
            Log::warning('ffmpeg indisponible ou en échec', ['error' => $e->getMessage()]);
        }

        return null;
    }
}
