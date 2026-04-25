<?php

namespace App\Jobs;

use App\Models\ProductVideo;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Log;

class ProcessVideoJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $tries = 3;
    public int $timeout = 300;

    public function __construct(public ProductVideo $video) {}

    public function handle(): void
    {
        try {
            $this->video->update(['processing_status' => 'processing']);

            $inputPath = Storage::disk('public')->path($this->video->video_path);

            // Vérifier que le fichier existe
            if (!file_exists($inputPath)) {
                throw new \Exception("Fichier vidéo introuvable : {$inputPath}");
            }

            // Générer thumbnail à 1 seconde
            $thumbDir = 'thumbnails/' . date('Y/m');
            Storage::disk('public')->makeDirectory($thumbDir);
            $thumbPath = $thumbDir . '/' . pathinfo($this->video->video_path, PATHINFO_FILENAME) . '.jpg';
            $thumbFullPath = Storage::disk('public')->path($thumbPath);

            // FFmpeg thumbnail (si disponible)
            $ffmpeg = 'ffmpeg';
            $thumbCmd = "{$ffmpeg} -i \"{$inputPath}\" -ss 00:00:01 -vframes 1 -q:v 2 \"{$thumbFullPath}\" 2>&1";
            exec($thumbCmd, $thumbOutput, $thumbCode);

            // Durée via ffprobe
            $duration = null;
            $probeCmd = "ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 \"{$inputPath}\" 2>&1";
            exec($probeCmd, $probeOutput, $probeCode);
            if ($probeCode === 0 && !empty($probeOutput[0])) {
                $duration = (int) round((float) $probeOutput[0]);
            }

            $this->video->update([
                'processing_status' => 'completed',
                'thumbnail_path'    => $thumbCode === 0 ? $thumbPath : null,
                'duration_seconds'  => $duration,
            ]);

        } catch (\Throwable $e) {
            Log::error('ProcessVideoJob failed', [
                'video_id' => $this->video->id,
                'error'    => $e->getMessage(),
            ]);
            $this->video->update(['processing_status' => 'failed']);
            throw $e;
        }
    }
}