<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('products', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('title', 200);
            $table->string('slug', 255)->unique();
            $table->text('description')->nullable();
            $table->foreignUuid('category_id')->constrained('categories');
            $table->decimal('price', 12, 2);
            $table->enum('currency', ['XOF', 'EUR', 'USD'])->default('XOF');
            $table->integer('stock_quantity')->default(1);
            $table->enum('condition', ['new', 'like_new', 'good', 'fair'])->default('new');
            $table->boolean('is_negotiable')->default(true);
            $table->enum('status', ['draft', 'active', 'sold', 'reserved', 'expired'])->default('draft');
            $table->foreignUuid('video_id')->nullable()->references('id')->on('product_videos')->nullOnDelete();
            $table->json('metadata')->nullable();
            $table->json('images')->nullable();
            $table->integer('view_count')->default(0);
            $table->integer('like_count')->default(0);
            $table->integer('share_count')->default(0);
            $table->timestamp('expires_at')->nullable();
            $table->timestamps();

            $table->index(['user_id', 'status']);
            $table->index(['category_id', 'price']);
            $table->index('slug');
            $table->fullText(['title', 'description']);
        });

        Schema::create('product_likes', function (Blueprint $table) {
            $table->id();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignUuid('product_id')->constrained('products')->cascadeOnDelete();
            $table->timestamps();
            $table->unique(['user_id', 'product_id']);
        });

        Schema::create('product_saves', function (Blueprint $table) {
            $table->id();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignUuid('product_id')->constrained('products')->cascadeOnDelete();
            $table->timestamps();
            $table->unique(['user_id', 'product_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('product_saves');
        Schema::dropIfExists('product_likes');
        Schema::dropIfExists('products');
    }
};
