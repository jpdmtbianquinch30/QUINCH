<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('admin_action_logs', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('admin_id');
            $table->string('action'); // user_suspended, kyc_verified, content_moderated, report_exported, etc.
            $table->string('target_type')->nullable(); // User, Product, Transaction, etc.
            $table->uuid('target_id')->nullable();
            $table->json('metadata')->nullable();
            $table->string('ip_address', 45)->nullable();
            $table->string('severity')->default('info'); // info, warning, critical
            $table->timestamps();

            $table->foreign('admin_id')->references('id')->on('users')->cascadeOnDelete();
            $table->index(['admin_id', 'created_at']);
            $table->index(['action', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('admin_action_logs');
    }
};
