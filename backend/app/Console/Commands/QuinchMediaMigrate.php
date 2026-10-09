<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\Storage;
use Throwable;

/**
 * Copie les médias du disque du serveur (storage/app/public) vers le stockage objet
 * configuré (MEDIA_DRIVER=s3). À lancer UNE fois, après avoir configuré le bucket :
 *
 *   php artisan quinch:media-migrate --dry-run     (compte, ne copie rien)
 *   php artisan quinch:media-migrate               (copie ; saute ce qui existe déjà)
 *   php artisan quinch:media-migrate --delete-source   (après vérification : libère le disque)
 *
 * Idempotent : peut être relancée sans risque après une interruption. Chaque fichier est
 * vérifié (taille identique) avant d'être considéré comme copié, et la source n'est jamais
 * supprimée sans --delete-source.
 */
class QuinchMediaMigrate extends Command
{
    protected $signature = 'quinch:media-migrate
        {--dry-run : Compter les fichiers sans rien copier}
        {--delete-source : Supprimer chaque fichier local une fois copié ET vérifié}
        {--allow-local : Autoriser une destination locale (tests uniquement)}';

    protected $description = 'Copie les médias du disque local vers le stockage objet (S3)';

    public function handle(): int
    {
        if (config('filesystems.disks.public.driver') === 'local' && !$this->option('allow-local')) {
            $this->error('MEDIA_DRIVER vaut « local » : il n\'y a pas de destination. Configurez MEDIA_DRIVER=s3 et le bucket (voir docs/STORAGE.md).');

            return self::FAILURE;
        }

        $source = Storage::disk('local_public');
        $target = Storage::disk('public');
        $dry    = (bool) $this->option('dry-run');

        $copied = $skipped = $failed = $deleted = 0;
        $bytes  = 0;

        foreach ($source->allFiles() as $path) {
            // Fichiers techniques (.gitignore...) : jamais des médias.
            if (str_starts_with(basename($path), '.')) {
                continue;
            }

            try {
                $size = $source->size($path);

                if ($target->exists($path) && $target->size($path) === $size) {
                    $skipped++;
                    $this->maybeDeleteSource($source, $path, $deleted);
                    continue;
                }

                if ($dry) {
                    $copied++;
                    $bytes += $size;
                    continue;
                }

                $stream = $source->readStream($path);
                try {
                    $target->writeStream($path, $stream);
                } finally {
                    if (is_resource($stream)) {
                        fclose($stream);
                    }
                }

                if (!$target->exists($path) || $target->size($path) !== $size) {
                    throw new \RuntimeException('taille différente après copie');
                }

                $copied++;
                $bytes += $size;
                $this->maybeDeleteSource($source, $path, $deleted);
            } catch (Throwable $e) {
                $failed++;
                $this->error("Échec : {$path} ({$e->getMessage()})");
            }
        }

        $verb = $dry ? 'à copier' : 'copiés';
        $this->info(sprintf(
            '%d fichier(s) %s (%s), %d déjà présent(s), %d échec(s)%s.',
            $copied,
            $verb,
            number_format($bytes / 1048576, 1, ',', ' ') . ' Mo',
            $skipped,
            $failed,
            $deleted > 0 ? ", {$deleted} supprimé(s) du disque local" : ''
        ));

        return $failed > 0 ? self::FAILURE : self::SUCCESS;
    }

    private function maybeDeleteSource($source, string $path, int &$deleted): void
    {
        if ($this->option('delete-source') && !$this->option('dry-run')) {
            $source->delete($path);
            $deleted++;
        }
    }
}
