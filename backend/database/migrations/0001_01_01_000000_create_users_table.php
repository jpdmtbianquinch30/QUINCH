<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('users', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('phone_number', 20)->unique();
            $table->string('email', 255)->unique()->nullable();
            $table->string('username', 50)->unique()->nullable();
            $table->string('full_name', 100)->nullable();
            $table->string('password');
            $table->string('avatar_url', 500)->nullable();
            $table->decimal('trust_score', 3, 2)->default(0.50);
            $table->enum('kyc_status', ['pending', 'verified', 'rejected'])->default('pending');
            $table->json('kyc_data')->nullable();
            $table->string('city', 100)->nullable();
            $table->string('region', 100)->nullable();
            $table->decimal('latitude', 10, 8)->nullable();
            $table->decimal('longitude', 11, 8)->nullable();
            $table->boolean('is_seller')->default(false);
            $table->boolean('is_buyer')->default(false);
            $table->enum('role', ['user', 'admin', 'super_admin'])->default('user');
            $table->enum('security_level', ['low', 'medium', 'high'])->default('medium');
            $table->enum('account_status', ['active', 'suspended', 'banned', 'deactivated'])->default('active');
            $table->timestamp('last_suspicious_activity')->nullable();
            $table->string('otp_code', 6)->nullable();
            $table->timestamp('otp_expires_at')->nullable();
            $table->boolean('phone_verified')->default(false);
            $table->json('preferences')->nullable();
            $table->boolean('onboarding_completed')->default(false);
            $table->string('device_fingerprint')->nullable();
            $table->rememberToken();
            $table->timestamps();

            $table->index('trust_score');
            $table->index(['latitude', 'longitude']);
        });

        Schema::create('password_reset_tokens', function (Blueprint $table) {
            $table->string('email')->primary();
            $table->string('token');
            $table->timestamp('created_at')->nullable();
        });

        Schema::create('sessions', function (Blueprint $table) {
            $table->string('id')->primary();
            $table->foreignUuid('user_id')->nullable()->index();
            $table->string('ip_address', 45)->nullable();
            $table->text('user_agent')->nullable();
            $table->longText('payload');
            $table->integer('last_activity')->index();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('sessions');
        Schema::dropIfExists('password_reset_tokens');
        Schema::dropIfExists('users');
    }
};
