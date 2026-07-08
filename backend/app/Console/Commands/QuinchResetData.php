<?php

namespace App\Console\Commands;

use App\Models\Conversation;
use App\Models\Notification;
use App\Models\Product;
use App\Models\ProductVideo;
use App\Models\Transaction;
use App\Models\User;
use Illuminate\Console\Command;

/**
 * Remplace l'ancien endpoint HTTP POST /admin/system/reset.
 *
 * Une action aussi destructrice (efface transactions, produits, vidéos,
 * conversations, notifications et tous les utilisateurs non-admin) ne doit
 * jamais être accessible via une route HTTP, même protégée par un rôle
 * admin : un token qui fuite, un bug de middleware, ou un reverse-proxy mal
 * configuré suffiraient à vider toute la base. Cette commande ne peut être
 * exécutée que depuis le serveur (SSH / CLI Docker), avec confirmation.
 */
class QuinchResetData extends Command
{
    protected $signature = 'quinch:reset-data {--force : Ignorer la confirmation}';

    protected $description = 'Réinitialise complètement les données QUINCH (transactions, produits, vidéos, conversations, notifications, utilisateurs non-admin)';

    public function handle(): int
    {
        if (!app()->environment(['local', 'testing', 'staging'])) {
            $this->error('Cette commande est bloquée en production. Utilisez-la uniquement en local/staging.');
            return self::FAILURE;
        }

        if (!$this->option('force') && !$this->confirm('Ceci va supprimer TOUTES les données (sauf les comptes admin). Continuer ?')) {
            $this->info('Annulé.');
            return self::SUCCESS;
        }

        Transaction::query()->delete();
        Product::query()->delete();
        ProductVideo::query()->delete();
        Conversation::query()->delete();
        Notification::query()->delete();
        User::whereNotIn('role', ['admin', 'super_admin'])->delete();

        $this->info('Reset terminé : utilisateurs, vidéos, produits et transactions supprimés.');
        return self::SUCCESS;
    }
}
