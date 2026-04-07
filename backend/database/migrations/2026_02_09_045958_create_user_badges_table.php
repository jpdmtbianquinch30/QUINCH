<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('user_badges', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('user_id');
            $table->string('badge_type', 50); // verified, top_seller, fast_shipper, loyal_customer, etc.
            $table->string('badge_level', 20)->nullable(); // bronze, silver, gold, platinum
            $table->uuid('awarded_by')->nullable(); // admin who awarded manually
            $table->text('reason')->nullable();
            $table->timestamp('expires_at')->nullable();
            $table->timestamps();

            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
            $table->foreign('awarded_by')->references('id')->on('users')->nullOnDelete();
            $table->unique(['user_id', 'badge_type']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('user_badges');
    }
};
