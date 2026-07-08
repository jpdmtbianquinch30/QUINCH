<?php

namespace App\Console\Commands;

use App\Models\Product;
use App\Models\ProductVideo;
use Illuminate\Console\Command;

/**
 * Remplace l'ancien endpoint HTTP POST /admin/moderation/delete-all-videos.
 * Même logique que QuinchResetData : action destructrice réservée au CLI.
 */
class QuinchDeleteAllVideos extends Command
{
    protected $signature = 'quinch:delete-all-videos {--force : Ignorer la confirmation}';

    protected $description = 'Supprime toutes les vidéos et les produits qui leur sont associés';

    public function handle(): int
    {
        if (!app()->environment(['local', 'testing', 'staging'])) {
            $this->error('Cette commande est bloquée en production. Utilisez-la uniquement en local/staging.');
            return self::FAILURE;
        }

        if (!$this->option('force') && !$this->confirm('Ceci va supprimer TOUTES les vidéos et produits associés. Continuer ?')) {
            $this->info('Annulé.');
            return self::SUCCESS;
        }

        Product::whereNotNull('video_id')->delete();
        ProductVideo::query()->delete();

        $this->info('Toutes les vidéos et produits associés ont été supprimés.');
        return self::SUCCESS;
    }
}
