<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('negotiations', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('buyer_id');
            $table->uuid('seller_id');
            $table->uuid('product_id');
            $table->decimal('proposed_price', 12, 2);
            $table->decimal('counter_price', 12, 2)->nullable();
            $table->string('status')->default('pending'); // pending, accepted, rejected, countered, expired
            $table->text('buyer_message')->nullable();
            $table->text('seller_message')->nullable();
            $table->timestamp('expires_at');
            $table->timestamps();

            $table->foreign('buyer_id')->references('id')->on('users')->cascadeOnDelete();
            $table->foreign('seller_id')->references('id')->on('users')->cascadeOnDelete();
            $table->foreign('product_id')->references('id')->on('products')->cascadeOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('negotiations');
    }
};
