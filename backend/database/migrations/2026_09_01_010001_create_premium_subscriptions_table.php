<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('premium_subscriptions', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();

            $table->enum('plan', ['monthly', 'annual']);
            $table->decimal('amount', 10, 2);
            $table->string('currency', 3)->default('XOF');

            // pending    : en attente de confirmation du paiement (webhook)
            // active     : abonnement en cours
            // expired    : arrivé à échéance naturellement
            // cancelled  : paiement échoué/annulé avant activation
            $table->enum('status', ['pending', 'active', 'expired', 'cancelled'])->default('pending');

            $table->string('payment_method')->default('wave');
            $table->string('payment_gateway_id')->nullable();

            $table->timestamp('starts_at')->nullable();
            $table->timestamp('expires_at')->nullable();

            $table->timestamps();

            $table->index(['user_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('premium_subscriptions');
    }
};
