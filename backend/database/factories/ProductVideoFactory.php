<?php

namespace Database\Factories;

use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends \Illuminate\Database\Eloquent\Factories\Factory<\App\Models\ProductVideo>
 */
class ProductVideoFactory extends Factory
{
    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'video_path' => 'videos/' . fake()->uuid() . '.mp4',
            'thumbnail_path' => 'thumbnails/' . fake()->uuid() . '.jpg',
            'duration_seconds' => fake()->numberBetween(5, 60),
            'format' => 'mp4',
            'size_bytes' => fake()->numberBetween(500_000, 50_000_000),
            'processing_status' => 'completed',
            'moderation_status' => 'approved',
        ];
    }

    /**
     * Vidéo pas encore modérée (état par défaut à l'upload).
     */
    public function pendingModeration(): static
    {
        return $this->state(fn (array $attributes) => [
            'moderation_status' => 'pending',
        ]);
    }

    /**
     * Vidéo rejetée par la modération.
     */
    public function rejected(): static
    {
        return $this->state(fn (array $attributes) => [
            'moderation_status' => 'rejected',
        ]);
    }
}
