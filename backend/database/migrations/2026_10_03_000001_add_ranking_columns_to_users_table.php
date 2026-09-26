<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

// Colonnes utilisees par RankingController (classements vendeurs/acheteurs/
// produits/profils) et PublicProfileController (compteur de vues de profil).
// Elles etaient deja referencees dans le modele User sans jamais avoir ete
// creees en base.
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            if (!Schema::hasColumn('users', 'ranking_opt_in')) {
                $table->boolean('ranking_opt_in')->default(false)->after('is_premium');
            }
            if (!Schema::hasColumn('users', 'ranking_anonymous')) {
                $table->boolean('ranking_anonymous')->default(false)->after('ranking_opt_in');
            }
            if (!Schema::hasColumn('users', 'profile_views_count')) {
                $table->unsignedInteger('profile_views_count')->default(0)->after('ranking_anonymous');
            }
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            if (Schema::hasColumn('users', 'ranking_opt_in')) {
                $table->dropColumn('ranking_opt_in');
            }
            if (Schema::hasColumn('users', 'ranking_anonymous')) {
                $table->dropColumn('ranking_anonymous');
            }
            if (Schema::hasColumn('users', 'profile_views_count')) {
                $table->dropColumn('profile_views_count');
            }
        });
    }
};
