<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('products', function (Blueprint $table) {
            $table->unsignedInteger('listing_fee_amount')->default(0)->after('status');
            // none   : compte premium, aucun frais applicable
            // pending: frais dû, en attente de paiement (produit en 'draft')
            // paid   : frais réglé, produit publié
            // failed : paiement échoué/annulé, produit reste en 'draft'
            $table->enum('listing_fee_status', ['none', 'pending', 'paid', 'failed'])->default('none')->after('listing_fee_amount');
            $table->string('listing_fee_gateway_id')->nullable()->after('listing_fee_status');
        });
    }

    public function down(): void
    {
        Schema::table('products', function (Blueprint $table) {
            $table->dropColumn(['listing_fee_amount', 'listing_fee_status', 'listing_fee_gateway_id']);
        });
    }
};