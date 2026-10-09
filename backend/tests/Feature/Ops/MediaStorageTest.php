<?php

namespace Tests\Feature\Ops;

use App\Jobs\PurgeAnonymizedAccountData;
use App\Models\Product;
use App\Models\ProductVideo;
use App\Models\User;
use App\Support\MediaUrl;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

/**
 * Phase 6 : médias servis par le disque local OU par un stockage objet + CDN.
 */
class MediaStorageTest extends TestCase
{
    use RefreshDatabase;

    // ─── URL des médias ──────────────────────────────────────────────────────

    public function test_without_cdn_media_urls_point_to_the_api(): void
    {
        config(['media.url' => null]);

        $this->assertSame(url('/storage/products/a.jpg'), MediaUrl::for('products/a.jpg'));
        $this->assertSame(url('/storage/avatars/u/a.jpg'), MediaUrl::for('/storage/avatars/u/a.jpg'));
        $this->assertSame('https://lh3.googleusercontent.com/x', MediaUrl::for('https://lh3.googleusercontent.com/x'));
        $this->assertNull(MediaUrl::for(null));
        $this->assertNull(MediaUrl::for(''));
    }

    public function test_with_cdn_media_urls_point_to_the_cdn(): void
    {
        config(['media.url' => 'https://media.quinch.sn/']);

        $this->assertSame('https://media.quinch.sn/products/a.jpg', MediaUrl::for('products/a.jpg'));
        $this->assertSame('https://media.quinch.sn/avatars/u/a.jpg', MediaUrl::for('/storage/avatars/u/a.jpg'));
        // Une URL déjà complète n'est jamais réécrite.
        $this->assertSame('https://lh3.googleusercontent.com/x', MediaUrl::for('https://lh3.googleusercontent.com/x'));
        // Un chemin du site qui n'est pas un média reste sur le site.
        $this->assertSame(url('/images/default.png'), MediaUrl::for('/images/default.png'));
    }

    public function test_path_extracts_the_disk_path_from_local_and_cdn_urls(): void
    {
        config(['media.url' => 'https://media.quinch.sn']);

        $this->assertSame('messages/x.jpg', MediaUrl::path('https://media.quinch.sn/messages/x.jpg?v=2'));
        $this->assertSame('messages/x.jpg', MediaUrl::path('https://api.quinch.sn/storage/messages/x.jpg'));
        $this->assertSame('messages/x.jpg', MediaUrl::path('/storage/messages/x.jpg'));
        $this->assertNull(MediaUrl::path('https://example.com/other.jpg'));
        $this->assertNull(MediaUrl::path('/storage/../.env'));
        $this->assertNull(MediaUrl::path(''));
    }

    public function test_model_accessors_use_the_cdn(): void
    {
        config(['media.url' => 'https://media.quinch.sn']);

        $user = User::factory()->create(['avatar_url' => '/storage/avatars/u/a.jpg']);
        $this->assertSame('https://media.quinch.sn/avatars/u/a.jpg', $user->avatar_url);

        $product = Product::factory()->create([
            'poster_url' => 'products/posters/p.jpg',
            'images' => ['products/images/a.jpg'],
        ]);
        $this->assertSame('https://media.quinch.sn/products/posters/p.jpg', $product->poster_full_url);
        $this->assertSame(['https://media.quinch.sn/products/images/a.jpg'], $product->images);
    }

    // ─── Lecture des vidéos en stockage objet ────────────────────────────────

    public function test_with_object_storage_the_stream_redirects_to_the_cdn(): void
    {
        config([
            'filesystems.disks.public.driver' => 's3',
            'media.url' => 'https://media.quinch.sn',
        ]);
        $video = ProductVideo::factory()->create([
            'video_path' => 'videos/2026/10/v.mp4',
            'thumbnail_path' => 'thumbnails/2026/10/v.jpg',
        ]);

        $this->get("/api/v1/videos/{$video->id}/stream")
            ->assertRedirect('https://media.quinch.sn/videos/2026/10/v.mp4');

        $this->get("/api/v1/videos/{$video->id}/thumbnail")
            ->assertRedirect('https://media.quinch.sn/thumbnails/2026/10/v.jpg');

        $this->get('/api/v1/videos/stream-path?path=' . urlencode('videos/2026/10/v.mp4'))
            ->assertRedirect('https://media.quinch.sn/videos/2026/10/v.mp4');
    }

    public function test_a_rejected_video_is_never_redirected_to_the_cdn(): void
    {
        config([
            'filesystems.disks.public.driver' => 's3',
            'media.url' => 'https://media.quinch.sn',
        ]);
        $video = ProductVideo::factory()->rejected()->create(['video_path' => 'videos/2026/10/bad.mp4']);

        $this->get("/api/v1/videos/{$video->id}/stream")->assertNotFound();
    }

    // ─── Effacement : les pièces jointes servies par le CDN sont supprimées ──

    public function test_purge_deletes_message_files_referenced_by_cdn_urls(): void
    {
        Storage::fake('public');
        config(['media.url' => 'https://media.quinch.sn']);

        $user = User::factory()->create();
        $user->forceFill(['anonymized_at' => now()->subDays(40)])->save();

        $other = User::factory()->create();
        $conversationId = (string) \Illuminate\Support\Str::uuid();

        Storage::disk('public')->put('messages/images/a.jpg', 'x');
        Storage::disk('public')->put('messages/unrelated.txt', 'x');

        DB::table('conversations')->insert([
            'id' => $conversationId,
            'buyer_id' => $user->id,
            'seller_id' => $other->id,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        DB::table('messages')->insert([
            'id' => (string) \Illuminate\Support\Str::uuid(),
            'conversation_id' => $conversationId,
            'sender_id' => $user->id,
            'body' => 'Voici la photo',
            'type' => 'image',
            'metadata' => json_encode([
                'file_url' => 'https://media.quinch.sn/messages/images/a.jpg',
                // Une simple chaîne ne doit JAMAIS désigner un fichier à supprimer.
                'file_name' => 'messages/unrelated.txt',
            ]),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        (new PurgeAnonymizedAccountData)->handle();

        Storage::disk('public')->assertMissing('messages/images/a.jpg');
        Storage::disk('public')->assertExists('messages/unrelated.txt');
    }

    // ─── Migration du disque local vers le stockage objet ────────────────────

    public function test_media_migrate_refuses_to_run_without_a_remote_destination(): void
    {
        $this->artisan('quinch:media-migrate')->assertExitCode(1);
    }

    public function test_media_migrate_copies_missing_files_and_is_idempotent(): void
    {
        Storage::fake('local_public');
        Storage::fake('public');

        Storage::disk('local_public')->put('products/a.jpg', 'AAAA');
        Storage::disk('local_public')->put('videos/2026/10/v.mp4', 'VIDEO');
        Storage::disk('public')->put('products/a.jpg', 'AAAA'); // déjà migré

        $this->artisan('quinch:media-migrate', ['--allow-local' => true])->assertExitCode(0);

        Storage::disk('public')->assertExists('videos/2026/10/v.mp4');
        $this->assertSame('VIDEO', Storage::disk('public')->get('videos/2026/10/v.mp4'));
        Storage::disk('local_public')->assertExists('videos/2026/10/v.mp4'); // source conservée

        // Deuxième passage : rien de plus à copier.
        $this->artisan('quinch:media-migrate', ['--allow-local' => true])
            ->expectsOutputToContain('0 fichier(s) copiés')
            ->assertExitCode(0);
    }

    public function test_media_migrate_dry_run_copies_nothing_and_delete_source_only_after_verification(): void
    {
        Storage::fake('local_public');
        Storage::fake('public');
        Storage::disk('local_public')->put('products/a.jpg', 'AAAA');

        $this->artisan('quinch:media-migrate', ['--allow-local' => true, '--dry-run' => true])->assertExitCode(0);
        Storage::disk('public')->assertMissing('products/a.jpg');

        $this->artisan('quinch:media-migrate', ['--allow-local' => true, '--delete-source' => true])->assertExitCode(0);
        Storage::disk('public')->assertExists('products/a.jpg');
        Storage::disk('local_public')->assertMissing('products/a.jpg');
    }
}
