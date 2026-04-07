<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('products', function (Blueprint $table) {
            // 'fixed' = seller sets fixed delivery fee for buyer, 'contact' = buyer contacts seller
            $table->string('delivery_option', 20)->default('contact')->after('payment_methods');
            // Delivery fee in F CFA (only relevant when delivery_option = 'seller')
            $table->unsignedInteger('delivery_fee')->default(0)->after('delivery_option');
        });
    }

    public function down(): void
    {
        Schema::table('products', function (Blueprint $table) {
            $table->dropColumn(['delivery_option', 'delivery_fee']);
        });
    }
};
