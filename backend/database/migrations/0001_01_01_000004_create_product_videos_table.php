<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('product_videos', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('video_path', 500);
            $table->string('thumbnail_path', 500)->nullable();
            $table->integer('duration_seconds')->nullable();
            $table->string('format', 10)->nullable();
            $table->bigInteger('size_bytes')->nullable();
            $table->char('hash_sha256', 64)->unique()->nullable();
            $table->enum('processing_status', ['pending', 'processing', 'completed', 'failed'])->default('pending');
            $table->enum('moderation_status', ['pending', 'approved', 'rejected', 'flagged'])->default('pending');
            $table->integer('view_count')->default(0);
            $table->decimal('engagement_score', 5, 2)->default(0.00);
            $table->timestamps();

            $table->index(['user_id', 'created_at']);
            $table->index('moderation_status');
            $table->index('engagement_score');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('product_videos');
    }
};
