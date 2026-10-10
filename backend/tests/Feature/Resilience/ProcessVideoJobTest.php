<?php

namespace Tests\Feature\Resilience;

use App\Jobs\ProcessVideoJob;
use App\Models\ProductVideo;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

/**
 * Régression : « Fichier vidéo introuvable » faisait réessayer le job 3 fois pour rien
 * et laissait la vidéo bloquée en « processing ». Le job échoue maintenant tout de suite,
 * proprement, et marque la vidéo « failed ».
 */
class ProcessVideoJobTest extends TestCase
{
    use RefreshDatabase;

    public function test_missing_file_marks_the_video_failed_without_crashing_the_worker(): void
    {
        Storage::fake('public');

        $video = ProductVideo::factory()->create([
            'video_path'        => 'videos/2026/10/absent.mp4',
            'thumbnail_path'    => null,
            'processing_status' => 'pending',
        ]);

        // File « sync » en test : un échec définitif ne doit pas lever d'exception.
        ProcessVideoJob::dispatchSync($video);

        $this->assertSame('failed', $video->fresh()->processing_status);
    }

    public function test_missing_file_never_goes_through_the_processing_status(): void
    {
        Storage::fake('public');

        $video = ProductVideo::factory()->create([
            'video_path'        => 'videos/2026/10/absent.mp4',
            'thumbnail_path'    => null,
            'processing_status' => 'pending',
        ]);

        ProcessVideoJob::dispatchSync($video);

        // Jamais bloquée en « processing » : c'était le symptôme du bug.
        $this->assertNotSame('processing', $video->fresh()->processing_status);
    }

    public function test_existing_file_is_processed_even_if_ffmpeg_is_unavailable(): void
    {
        Storage::fake('public');
        Storage::disk('public')->put('videos/2026/10/ok.mp4', 'not-a-real-video');

        $video = ProductVideo::factory()->create([
            'video_path'        => 'videos/2026/10/ok.mp4',
            'thumbnail_path'    => null,
            'processing_status' => 'pending',
        ]);

        ProcessVideoJob::dispatchSync($video);

        // Une miniature ou une durée manquante ne rend pas la vidéo invalide.
        $this->assertSame('completed', $video->fresh()->processing_status);
    }

    public function test_job_is_dropped_silently_when_the_video_was_deleted_meanwhile(): void
    {
        $this->assertTrue((new ProcessVideoJob(ProductVideo::factory()->make()))->deleteWhenMissingModels);
    }
}
