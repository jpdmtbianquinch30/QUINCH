<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * 1) Badges pilotés par l'admin : table `badge_definitions` (nom, icône, couleur,
 *    description, « comment l'obtenir », règle automatique, zones d'affichage).
 *    Les 10 badges historiques sont recréés ici pour ne rien perdre.
 * 2) `user_badges.source` : 'manual' (attribué par un humain) ou 'auto' (posé /
 *    retiré par le système selon la règle du badge).
 * 3) Contestation depuis une notification : `moderation_appeals` mémorise la
 *    notification d'origine et l'admin concerné (celui qui a pris la décision).
 */
return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable('badge_definitions')) {
            Schema::create('badge_definitions', function (Blueprint $table) {
                $table->uuid('id')->primary();
                $table->string('key', 40)->unique();
                $table->string('name', 60);
                $table->string('description', 300)->nullable();
                $table->string('how_to_get', 400)->nullable();
                $table->string('icon', 60)->default('stars');
                $table->string('color', 9)->default('#6366f1');
                $table->string('auto_rule', 30)->nullable();      // null = badge manuel
                $table->unsignedInteger('auto_threshold')->nullable();
                $table->json('zones');                            // zones d'affichage
                $table->boolean('is_active')->default(true);
                $table->boolean('is_system')->default(false);     // badge d'origine : désactivable, pas supprimable
                $table->boolean('sellers_can_award')->default(false);
                $table->integer('sort_order')->default(0);
                $table->uuid('created_by')->nullable();
                $table->timestamps();

                $table->index(['is_active', 'sort_order']);
            });

            $zones = ['feed', 'explorer', 'video_feed', 'product_detail', 'seller_profile', 'messages', 'search', 'notifications', 'rankings', 'profile'];
            $now = now();
            $rows = [
                ['verified', 'Vérifié', 'Identité vérifiée par l\'équipe QUINCH.', 'Faites vérifier votre identité (KYC) : le badge est posé automatiquement.', 'verified', '#4f6ef7', 'kyc_verified', null, false],
                ['premium', 'Premium', 'Vendeur abonné à QUINCH Premium.', 'Souscrivez à QUINCH Premium : le badge est actif tant que l\'abonnement est valide.', 'workspace_premium', '#f59e0b', 'premium', null, false],
                ['top_seller', 'Top Vendeur', 'Vendeur reconnu pour la qualité de son service.', 'Attribué par l\'équipe aux meilleurs vendeurs.', 'emoji_events', '#f59e0b', null, null, false],
                ['fast_shipper', 'Livraison Express', 'Livre rapidement ses commandes.', 'Attribué par l\'équipe aux vendeurs les plus rapides.', 'local_shipping', '#22c55e', null, null, false],
                ['loyal_customer', 'Client Fidèle', 'Acheteur de confiance, reconnu par un vendeur.', 'Achetez chez un vendeur : il peut vous attribuer ce badge.', 'favorite', '#ef4444', null, null, true],
                ['active_reviewer', 'Reviewer Actif', 'Laisse régulièrement des avis utiles.', 'Attribué par l\'équipe aux contributeurs d\'avis.', 'rate_review', '#8b5cf6', null, null, false],
                ['first_sale', 'Première Vente', 'A réalisé sa première vente.', 'Finalisez votre première vente : badge automatique.', 'celebration', '#ec4899', 'sales_completed', 1, false],
                ['hundred_sales', '100 Ventes', 'A finalisé 100 ventes.', 'Atteignez 100 ventes finalisées : badge automatique.', 'military_tech', '#f59e0b', 'sales_completed', 100, false],
                ['ambassador', 'Ambassadeur', 'Ambassadeur de la communauté QUINCH.', 'Attribué par l\'équipe aux membres qui font rayonner QUINCH.', 'campaign', '#3b82f6', null, null, false],
                ['one_year', '1 an sur QUINCH', 'Membre depuis plus d\'un an.', 'Restez membre 365 jours : badge automatique.', 'cake', '#ec4899', 'account_age_days', 365, false],
            ];

            foreach ($rows as $i => [$key, $name, $desc, $how, $icon, $color, $rule, $threshold, $sellers]) {
                DB::table('badge_definitions')->insert([
                    'id' => (string) \Illuminate\Support\Str::uuid(),
                    'key' => $key, 'name' => $name, 'description' => $desc, 'how_to_get' => $how,
                    'icon' => $icon, 'color' => $color, 'auto_rule' => $rule, 'auto_threshold' => $threshold,
                    'zones' => json_encode($zones), 'is_active' => true, 'is_system' => true,
                    'sellers_can_award' => $sellers, 'sort_order' => $i * 10,
                    'created_at' => $now, 'updated_at' => $now,
                ]);
            }
        }

        if (!Schema::hasColumn('user_badges', 'source')) {
            Schema::table('user_badges', function (Blueprint $table) {
                $table->string('source', 10)->default('manual');
            });
        }

        if (!Schema::hasColumn('moderation_appeals', 'notification_id')) {
            Schema::table('moderation_appeals', function (Blueprint $table) {
                $table->uuid('notification_id')->nullable();
                $table->uuid('concerned_admin_id')->nullable();
                $table->index('concerned_admin_id');
            });
        }
    }

    public function down(): void
    {
        Schema::table('moderation_appeals', function (Blueprint $table) {
            if (Schema::hasColumn('moderation_appeals', 'notification_id')) {
                $table->dropIndex(['concerned_admin_id']);
                $table->dropColumn(['notification_id', 'concerned_admin_id']);
            }
        });
        Schema::table('user_badges', function (Blueprint $table) {
            if (Schema::hasColumn('user_badges', 'source')) {
                $table->dropColumn('source');
            }
        });
        Schema::dropIfExists('badge_definitions');
    }
};
