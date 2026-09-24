<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Un produit "tague" dans une conversation (achat direct ou tag manuel
     * du vendeur) — table dediee plutot qu'un simple message de chat, pour
     * pouvoir faire evoluer son etat apres coup (flou, publication au
     * repertoire) sans reecrire l'historique des messages, et pour pouvoir
     * lister "tous les produits tagues de cette conversation" ailleurs
     * (ex. repertoire vendeur) sans reparser des messages.
     */
    public function up(): void
    {
        Schema::create('conversation_product_tags', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('conversation_id');
            $table->uuid('product_id');
            $table->uuid('tagged_by')->nullable();
            $table->uuid('transaction_id')->nullable();

            // "Flouter le produit tague" : masque visuellement l'image du
            // produit dans la carte affichee au fil de la discussion (ex.
            // negociation en cours, produit reserve, etc.)
            $table->boolean('is_blurred')->default(false);

            // "Publier dans le repertoire" : le vendeur choisit de garder ce
            // produit tague visible/mis en avant sur son repertoire public
            // (profil vendeur), au-dela de la simple discussion.
            $table->boolean('published_to_directory')->default(false);

            $table->timestamps();

            $table->foreign('conversation_id')->references('id')->on('conversations')->cascadeOnDelete();
            $table->foreign('product_id')->references('id')->on('products')->cascadeOnDelete();
            $table->foreign('tagged_by')->references('id')->on('users')->nullOnDelete();
            $table->foreign('transaction_id')->references('id')->on('transactions')->nullOnDelete();

            $table->unique(['conversation_id', 'product_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('conversation_product_tags');
    }
};
