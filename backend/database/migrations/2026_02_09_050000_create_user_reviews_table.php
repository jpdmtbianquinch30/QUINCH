<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('user_reviews', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('reviewer_id');
            $table->uuid('seller_id');
            $table->uuid('transaction_id')->nullable();
            $table->tinyInteger('rating'); // 1-5
            $table->text('comment')->nullable();
            $table->decimal('delivery_rating', 2, 1)->nullable();
            $table->decimal('communication_rating', 2, 1)->nullable();
            $table->decimal('accuracy_rating', 2, 1)->nullable();
            $table->text('seller_response')->nullable();
            $table->timestamp('seller_responded_at')->nullable();
            $table->timestamps();

            $table->foreign('reviewer_id')->references('id')->on('users')->cascadeOnDelete();
            $table->foreign('seller_id')->references('id')->on('users')->cascadeOnDelete();
            $table->foreign('transaction_id')->references('id')->on('transactions')->nullOnDelete();
            $table->unique(['reviewer_id', 'transaction_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('user_reviews');
    }
};
