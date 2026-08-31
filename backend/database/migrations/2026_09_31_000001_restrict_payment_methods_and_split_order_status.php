<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // On ne garde que Wave et Orange Money. Les transactions existantes
        // (dev/staging) sur cash_delivery/free_money basculent sur 'wave'
        // pour respecter la nouvelle contrainte — à ignorer si la base est vide.
        DB::statement("UPDATE transactions SET payment_method = 'wave' WHERE payment_method NOT IN ('orange_money', 'wave') OR payment_method IS NULL");

        DB::statement('ALTER TABLE transactions DROP CONSTRAINT IF EXISTS transactions_payment_method_check');
        DB::statement("ALTER TABLE transactions ADD CONSTRAINT transactions_payment_method_check CHECK (payment_method IN ('orange_money', 'wave'))");

        // payment_status = uniquement l'état du paiement côté gateway.
        // order_status = uniquement l'état de traitement de la commande.
        // (avant, les deux étaient mélangés dans payment_status, d'où le bug
        // 500 sur l'annulation : 'cancelled' n'existe pas dans son enum.)
        Schema::table('transactions', function (Blueprint $table) {
            $table->timestamp('paid_at')->nullable()->after('completed_at');
            $table->string('order_status', 30)->default('pending_payment')->after('payment_status');
        });

        DB::statement("ALTER TABLE transactions ADD CONSTRAINT transactions_order_status_check CHECK (order_status IN ('pending_payment', 'processing', 'shipped', 'delivered', 'completed', 'cancelled', 'disputed'))");

        DB::statement("UPDATE transactions SET order_status = CASE
            WHEN payment_status = 'completed' THEN 'completed'
            ELSE 'pending_payment'
        END");
    }

    public function down(): void
    {
        DB::statement('ALTER TABLE transactions DROP CONSTRAINT IF EXISTS transactions_order_status_check');
        Schema::table('transactions', function (Blueprint $table) {
            $table->dropColumn(['order_status', 'paid_at']);
        });
        DB::statement('ALTER TABLE transactions DROP CONSTRAINT IF EXISTS transactions_payment_method_check');
        DB::statement("ALTER TABLE transactions ADD CONSTRAINT transactions_payment_method_check CHECK (payment_method IN ('orange_money', 'wave', 'free_money', 'cash_delivery'))");
    }
};