<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * AdminUserController::ban() écrivait déjà dans 'status', 'ban_reason' et
 * 'banned_at' — mais aucune migration ne créait ces colonnes sur `users`
 * (seul `account_status` existe). Résultat : le bannissement ne persistait
 * jamais réellement (silencieusement ignoré par le mass assignment guard),
 * seuls les tokens étaient révoqués. On ajoute les colonnes manquantes ici ;
 * le contrôleur est corrigé pour écrire dans `account_status` (colonne déjà
 * existante, valeur 'banned' déjà valide dans l'enum) plutôt que dans un
 * champ `status` qui n'a jamais existé.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('ban_reason', 500)->nullable()->after('account_status');
            $table->timestamp('banned_at')->nullable()->after('ban_reason');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['ban_reason', 'banned_at']);
        });
    }
};
