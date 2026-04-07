<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Enhance user_notifications table
        Schema::table('user_notifications', function (Blueprint $table) {
            $table->string('group_key')->nullable()->after('data');
            $table->integer('group_count')->default(1)->after('group_key');
            $table->string('priority', 10)->default('normal')->after('group_count'); // critical, normal, low
            $table->string('image_url')->nullable()->after('priority');
            $table->uuid('sender_id')->nullable()->after('image_url');

            $table->index('group_key');
            $table->index('type');
            $table->index('priority');
        });

        // Create notification preferences table
        Schema::create('notification_preferences', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('user_id');
            $table->string('type'); // message, follow, like, comment, review, transaction, system, admin
            $table->boolean('push_enabled')->default(true);
            $table->boolean('in_app_enabled')->default(true);
            $table->boolean('email_enabled')->default(false);
            $table->timestamps();

            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
            $table->unique(['user_id', 'type']);
        });
    }

    public function down(): void
    {
        Schema::table('user_notifications', function (Blueprint $table) {
            $table->dropIndex(['group_key']);
            $table->dropIndex(['type']);
            $table->dropIndex(['priority']);
            $table->dropColumn(['group_key', 'group_count', 'priority', 'image_url', 'sender_id']);
        });
        Schema::dropIfExists('notification_preferences');
    }
};
