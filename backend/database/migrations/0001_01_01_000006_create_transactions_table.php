<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('transactions', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('buyer_id')->constrained('users');
            $table->foreignUuid('seller_id')->constrained('users');
            $table->foreignUuid('product_id')->constrained('products');
            $table->decimal('amount', 12, 2);
            $table->enum('currency', ['XOF'])->default('XOF');
            $table->enum('payment_method', ['orange_money', 'wave', 'free_money', 'cash_delivery'])->nullable();
            $table->enum('payment_status', ['pending', 'processing', 'completed', 'failed', 'refunded'])->default('pending');
            $table->string('payment_gateway_id', 100)->nullable();
            $table->enum('security_check', ['pending', 'passed', 'failed', 'manual_review'])->default('pending');
            $table->enum('delivery_type', ['pickup', 'delivery', 'meetup'])->nullable();
            $table->json('delivery_address')->nullable();
            $table->decimal('transaction_fee', 10, 2)->default(0);
            $table->decimal('risk_score', 3, 2)->default(0.00);
            $table->integer('payment_failure_count')->default(0);
            $table->timestamp('completed_at')->nullable();
            $table->timestamps();

            $table->index(['buyer_id', 'created_at']);
            $table->index(['seller_id', 'created_at']);
            $table->index('payment_status');
            $table->index('security_check');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('transactions');
    }
};
