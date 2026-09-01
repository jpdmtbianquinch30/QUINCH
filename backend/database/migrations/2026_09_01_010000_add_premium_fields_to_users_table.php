<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->boolean('is_premium')->default(false)->after('trust_score');
            $table->enum('premium_plan', ['monthly', 'annual'])->nullable()->after('is_premium');
            $table->timestamp('premium_expires_at')->nullable()->after('premium_plan');

            $table->index(['is_premium', 'premium_expires_at']);
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropIndex(['is_premium', 'premium_expires_at']);
            $table->dropColumn(['is_premium', 'premium_plan', 'premium_expires_at']);
        });
    }
};
