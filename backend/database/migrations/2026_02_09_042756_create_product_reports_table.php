<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('product_reports', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('reporter_id');
            $table->uuid('product_id');
            $table->string('reason'); // fraud, inappropriate, counterfeit, spam, other
            $table->text('description')->nullable();
            $table->string('status')->default('pending'); // pending, reviewed, resolved, dismissed
            $table->uuid('reviewed_by')->nullable();
            $table->text('admin_notes')->nullable();
            $table->timestamps();

            $table->foreign('reporter_id')->references('id')->on('users')->cascadeOnDelete();
            $table->foreign('product_id')->references('id')->on('products')->cascadeOnDelete();
            $table->foreign('reviewed_by')->references('id')->on('users')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('product_reports');
    }
};
