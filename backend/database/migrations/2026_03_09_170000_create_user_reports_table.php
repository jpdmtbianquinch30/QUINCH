<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('user_reports', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('reporter_id');
            $table->uuid('reported_user_id');
            $table->string('reason'); // harassment, spam, inappropriate_content, fraud, impersonation, other
            $table->text('description')->nullable();
            $table->string('status')->default('pending'); // pending, reviewed, resolved, dismissed
            $table->uuid('reviewed_by')->nullable();
            $table->text('admin_notes')->nullable();
            $table->timestamps();

            $table->foreign('reporter_id')->references('id')->on('users')->cascadeOnDelete();
            $table->foreign('reported_user_id')->references('id')->on('users')->cascadeOnDelete();
            $table->foreign('reviewed_by')->references('id')->on('users')->nullOnDelete();

            // Prevent duplicate pending reports from same reporter on same user
            $table->unique(['reporter_id', 'reported_user_id', 'status'], 'unique_pending_report');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('user_reports');
    }
};
