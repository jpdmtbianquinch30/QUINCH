<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            // Stocke le nouveau numéro le temps de sa vérification par OTP,
            // sans jamais toucher à "phone_number" (l'identifiant de
            // connexion) tant que le nouveau numéro n'est pas confirmé.
            $table->string('pending_phone_number', 20)->nullable()->after('phone_number');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('pending_phone_number');
        });
    }
};
