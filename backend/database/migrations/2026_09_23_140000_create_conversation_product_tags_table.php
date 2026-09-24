<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('conversation_product_tags', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('conversation_id');
            $table->uuid('product_id');
            $table->uuid('tagged_by')->nullable();
            $table->uuid('transaction_id')->nullable();
            $table->timestamps();

            $table->foreign('conversation_id')->references('id')->on('conversations')->cascadeOnDelete();
            $table->foreign('product_id')->references('id')->on('products')->cascadeOnDelete();
            $table->foreign('tagged_by')->references('id')->on('users')->nullOnDelete();
            $table->foreign('transaction_id')->references('id')->on('transactions')->nullOnDelete();

            // Un seul tag par produit et par conversation : sert de garde-fou
            // contre la course critique geree dans ConversationTaggingService
            // (voir errorInfo 23505 catche la-bas).
            $table->unique(['conversation_id', 'product_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('conversation_product_tags');
    }
};
