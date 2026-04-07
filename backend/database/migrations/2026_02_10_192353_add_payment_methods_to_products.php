<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        $afterColumn = Schema::hasColumn('products', 'poster_url') ? 'poster_url' : 'images';

        Schema::table('products', function (Blueprint $table) use ($afterColumn) {
            $table->json('payment_methods')->nullable()->after($afterColumn);
        });
    }

    public function down(): void
    {
        Schema::table('products', function (Blueprint $table) {
            $table->dropColumn('payment_methods');
        });
    }
};
