<?php

namespace App\Jobs;

use App\Models\Product;
use App\Models\User;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Throwable;

/**
 * Effacement DÉFINITIF des contenus d'un compte supprimé, une fois le délai
 * `legal.retention.anonymized_content_days` écoulé (30 jours par défaut).
 *
 * Pourquoi ce délai : la suppression du compte anonymise tout de suite l'identité
 * (nom, e-mail, téléphone, localisation...), mais les annonces, médias et messages
 * restent un temps disponibles pour traiter un litige ou un signalement en cours.
 *
 * Ce qui est effacé :
 *  - fichiers des annonces (affiche, images) et des vidéos ; textes des annonces remplacés ;
 *  - fichiers joints aux messages envoyés ; texte des messages remplacé.
 * Ce qui est conservé (obligations comptables et preuve de modération) : les lignes de
 * transactions et d'abonnements, et le journal des décisions d'administration.
 *
 * Idempotent : un compte traité reçoit content_purged_at et n'est plus repris ; en cas
 * d'erreur sur un compte, il est simplement retenté le lendemain.
 */
class PurgeAnonymizedAccountData implements ShouldQueue
{
    use Dispatchable, Queueable;

    public int $timeout = 600;
    public int $tries = 1;

    private const MESSAGE_PLACEHOLDER = '[Message supprimé]';

    public function handle(): void
    {
        $days = max(1, (int) config('legal.retention.anonymized_content_days', 30));

        User::query()
            ->whereNotNull('anonymized_at')
            ->whereNull('content_purged_at')
            ->where('anonymized_at', '<=', now()->subDays($days))
            ->orderBy('anonymized_at')
            ->limit(200)
            ->get()
            ->each(function (User $user) {
                try {
                    $this->purge($user);
                } catch (Throwable $e) {
                    Log::error('Effacement des contenus d\'un compte supprimé impossible', [
                        'user_id' => $user->id,
                        'error'   => $e->getMessage(),
                    ]);
                }
            });
    }

    private function purge(User $user): void
    {
        $this->purgeProducts($user);
        $this->purgeVideos($user);
        $this->purgeMessages($user);

        $user->forceFill(['content_purged_at' => now()])->save();

        Log::info('Contenus d\'un compte supprimé effacés définitivement', ['user_id' => $user->id]);
    }

    private function purgeProducts(User $user): void
    {
        $disk = Storage::disk('public');

        Product::withTrashed()->where('user_id', $user->id)->chunkById(100, function ($products) use ($disk) {
            foreach ($products as $product) {
                $poster = $product->getRawOriginal('poster_url');
                if ($poster) {
                    $disk->delete($poster);
                }

                $rawImages = $product->getRawOriginal('images');
                foreach ($rawImages ? (json_decode($rawImages, true) ?? []) : [] as $path) {
                    if (is_string($path)) {
                        $disk->delete($path);
                    }
                }

                // La ligne reste (clé étrangère des transactions, comptabilité) ; son contenu disparaît.
                DB::table('products')->where('id', $product->id)->update([
                    'title'       => 'Annonce supprimée',
                    'slug'        => 'annonce-supprimee-' . $product->id,
                    'description' => null,
                    'images'      => null,
                    'poster_url'  => null,
                    'metadata'    => null,
                    'updated_at'  => now(),
                ]);
            }
        });
    }

    private function purgeVideos(User $user): void
    {
        $disk = Storage::disk('public');

        DB::table('product_videos')->where('user_id', $user->id)->orderBy('id')->chunkById(100, function ($videos) use ($disk) {
            foreach ($videos as $video) {
                foreach ([$video->video_path ?? null, $video->thumbnail_path ?? null] as $path) {
                    if (is_string($path) && $path !== '') {
                        $disk->delete($path);
                    }
                }
            }
        }, 'id');

        // products.video_id est en « nullOnDelete » : les annonces ne sont pas touchées.
        DB::table('product_videos')->where('user_id', $user->id)->delete();
    }

    private function purgeMessages(User $user): void
    {
        $disk = Storage::disk('public');

        DB::table('messages')->where('sender_id', $user->id)->orderBy('id')->chunkById(200, function ($messages) use ($disk) {
            foreach ($messages as $message) {
                $metadata = is_string($message->metadata ?? null) ? json_decode($message->metadata, true) : null;
                if (!is_array($metadata)) {
                    continue;
                }
                foreach ($metadata as $value) {
                    $path = $this->storagePath($value);
                    if ($path !== null) {
                        $disk->delete($path);
                    }
                }
            }
        }, 'id');

        DB::table('messages')->where('sender_id', $user->id)->update([
            'body'     => self::MESSAGE_PLACEHOLDER,
            'metadata' => null,
        ]);
    }

    /**
     * Chemin relatif au disque des médias d'une URL de média (locale « /storage/... » ou du CDN),
     * sinon null. Seules les URL sont acceptées : une simple chaîne des métadonnées (nom de
     * fichier, type MIME...) ne doit jamais désigner un fichier à supprimer.
     */
    private function storagePath(mixed $value): ?string
    {
        if (!is_string($value)) {
            return null;
        }

        if (!preg_match('#^https?://#i', $value) && !str_starts_with($value, '/storage/')) {
            return null;
        }

        return \App\Support\MediaUrl::path($value);
    }
}
