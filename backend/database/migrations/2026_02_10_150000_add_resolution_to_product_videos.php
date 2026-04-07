<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('product_videos', function (Blueprint $table) {
            $table->string('resolution', 10)->nullable()->after('format'); // e.g. 4k, 1080p, 720p, 480p
            $table->integer('width')->nullable()->after('resolution');
            $table->integer('height')->nullable()->after('width');
            $table->string('quality_label', 20)->nullable()->after('height'); // HD, Full HD, 4K, SD
            $table->string('source', 20)->default('upload')->after('quality_label'); // upload, camera
        });
    }

    public function down(): void
    {
        Schema::table('product_videos', function (Blueprint $table) {
            $table->dropColumn(['resolution', 'width', 'height', 'quality_label', 'source']);
        });
    }
};
