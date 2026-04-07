<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('fraud_detections', function (Blueprint $table) {
            $table->id();
            $table->foreignUuid('user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->enum('detection_type', [
                'multiple_accounts',
                'suspicious_payment',
                'fake_product',
                'review_manipulation',
                'location_spoofing',
            ]);
            $table->decimal('confidence_score', 3, 2);
            $table->json('evidence');
            $table->enum('status', ['pending_review', 'confirmed', 'dismissed', 'auto_resolved'])->default('pending_review');
            $table->enum('action_taken', ['none', 'warning', 'suspension', 'ban', 'payment_hold'])->default('none');
            $table->foreignUuid('reviewed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('reviewed_at')->nullable();
            $table->timestamps();

            $table->index(['user_id', 'status']);
            $table->index(['detection_type', 'created_at']);
            $table->index('confidence_score');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('fraud_detections');
    }
};
