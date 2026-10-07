<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            // Preuve du consentement : quand, et quelle version des textes a été acceptée.
            $table->timestamp('terms_accepted_at')->nullable();
            $table->string('terms_version', 20)->nullable();
            $table->string('privacy_version', 20)->nullable();
            // Date à laquelle les contenus d'un compte supprimé ont été effacés définitivement.
            $table->timestamp('content_purged_at')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['terms_accepted_at', 'terms_version', 'privacy_version', 'content_purged_at']);
        });
    }
};
