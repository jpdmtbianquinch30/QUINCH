<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Les avis étaient rattachés au vendeur seulement : un avis laissé sur un produit
 * apparaissait sur toutes les autres annonces du même vendeur.
 * On rattache désormais chaque avis à son produit/service.
 * Les anciens avis (product_id NULL) restent visibles sur le profil vendeur.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('user_reviews', function (Blueprint $table) {
            $table->uuid('product_id')->nullable()->after('seller_id');
            $table->foreign('product_id')->references('id')->on('products')->nullOnDelete();
            $table->index(['product_id', 'created_at']);
        });

        // Un seul avis par personne et par produit (garanti par la base, même en cas de double clic).
        DB::statement('CREATE UNIQUE INDEX user_reviews_reviewer_product_unique ON user_reviews (reviewer_id, product_id) WHERE product_id IS NOT NULL');
    }

    public function down(): void
    {
        DB::statement('DROP INDEX IF EXISTS user_reviews_reviewer_product_unique');

        Schema::table('user_reviews', function (Blueprint $table) {
            $table->dropForeign(['product_id']);
            $table->dropIndex(['product_id', 'created_at']);
            $table->dropColumn('product_id');
        });
    }
};
