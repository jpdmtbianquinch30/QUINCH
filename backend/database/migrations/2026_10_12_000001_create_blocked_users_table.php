<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Utilisée par User::blockedUsers() et UserController::blockUser — la table n'existait dans
        // aucune migration : bloquer un utilisateur provoquait une erreur 500.
        if (Schema::hasTable('blocked_users')) {
            return;
        }

        Schema::create('blocked_users', function (Blueprint $table) {
            $table->uuid('user_id');
            $table->uuid('blocked_user_id');
            $table->timestamps();

            $table->primary(['user_id', 'blocked_user_id']);
            $table->index('blocked_user_id');
            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
            $table->foreign('blocked_user_id')->references('id')->on('users')->cascadeOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('blocked_users');
    }
};
