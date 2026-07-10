<?php

namespace Database\Factories;

use App\Models\Category;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends \Illuminate\Database\Eloquent\Factories\Factory<\App\Models\Product>
 */
class ProductFactory extends Factory
{
    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'title' => fake()->words(3, true),
            'description' => fake()->sentence(15),
            'category_id' => Category::factory(),
            'price' => fake()->numberBetween(1000, 500000),
            'currency' => 'XOF',
            'stock_quantity' => 1,
            'condition' => 'new',
            'is_negotiable' => false,
            'status' => 'active',
            'video_id' => ProductVideoFactory::new(),
        ];
    }

    /**
     * Produit encore en brouillon (pas publié).
     */
    public function draft(): static
    {
        return $this->state(fn (array $attributes) => ['status' => 'draft']);
    }

    /**
     * Produit négociable (feature V2, désactivée par défaut en V1).
     */
    public function negotiable(): static
    {
        return $this->state(fn (array $attributes) => ['is_negotiable' => true]);
    }

    /**
     * Attache une vidéo dont la modération est encore en attente.
     */
    public function withPendingVideo(): static
    {
        return $this->state(fn (array $attributes) => [
            'video_id' => ProductVideoFactory::new()->pendingModeration(),
        ]);
    }
}
