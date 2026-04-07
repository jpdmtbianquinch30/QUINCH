<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('user_follows', function (Blueprint $table) {
            $table->uuid('follower_id');
            $table->uuid('following_id');
            $table->boolean('notifications_enabled')->default(true);
            $table->timestamps();

            $table->primary(['follower_id', 'following_id']);
            $table->foreign('follower_id')->references('id')->on('users')->cascadeOnDelete();
            $table->foreign('following_id')->references('id')->on('users')->cascadeOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('user_follows');
    }
};
