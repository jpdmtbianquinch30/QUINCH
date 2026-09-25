<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('conversation_product_tags', function (Blueprint $table) {
            if (Schema::hasColumn('conversation_product_tags', 'is_blurred')) {
                $table->dropColumn('is_blurred');
            }
            if (Schema::hasColumn('conversation_product_tags', 'published_to_directory')) {
                $table->dropColumn('published_to_directory');
            }
        });
    }

    public function down(): void
    {
        Schema::table('conversation_product_tags', function (Blueprint $table) {
            if (!Schema::hasColumn('conversation_product_tags', 'is_blurred')) {
                $table->boolean('is_blurred')->default(false);
            }
            if (!Schema::hasColumn('conversation_product_tags', 'published_to_directory')) {
                $table->boolean('published_to_directory')->default(false);
            }
        });
    }
};
