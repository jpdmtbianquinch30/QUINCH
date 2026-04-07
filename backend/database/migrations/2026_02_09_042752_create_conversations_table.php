<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('conversations', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('buyer_id');
            $table->uuid('seller_id');
            $table->uuid('product_id')->nullable();
            $table->string('status')->default('active'); // active, archived, blocked
            $table->timestamp('last_message_at')->nullable();
            $table->timestamps();

            $table->foreign('buyer_id')->references('id')->on('users')->cascadeOnDelete();
            $table->foreign('seller_id')->references('id')->on('users')->cascadeOnDelete();
            $table->foreign('product_id')->references('id')->on('products')->nullOnDelete();
            $table->unique(['buyer_id', 'seller_id', 'product_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('conversations');
    }
};
