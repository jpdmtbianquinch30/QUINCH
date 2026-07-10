<?php

namespace Database\Factories;

use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

/**
 * @extends \Illuminate\Database\Eloquent\Factories\Factory<\App\Models\User>
 */
class UserFactory extends Factory
{
    protected static ?string $password;

    public function definition(): array
    {
        return [
            'phone_number' => '+221' . fake()->unique()->numerify('7########'),
            'full_name' => fake()->name(),
            'username' => fake()->unique()->userName(),
            'password' => static::$password ??= Hash::make('Password1'),
            'role' => 'user',
            'account_status' => 'active',
            'phone_verified' => true,
            'is_seller' => true,
            'is_buyer' => true,
            'onboarding_completed' => true,
            'remember_token' => Str::random(10),
        ];
    }

    /**
     * Compte administrateur.
     */
    public function admin(): static
    {
        return $this->state(fn (array $attributes) => [
            'role' => 'admin',
        ]);
    }

    /**
     * Compte super administrateur.
     */
    public function superAdmin(): static
    {
        return $this->state(fn (array $attributes) => [
            'role' => 'super_admin',
        ]);
    }

    /**
     * Compte suspendu.
     */
    public function suspended(): static
    {
        return $this->state(fn (array $attributes) => [
            'account_status' => 'suspended',
        ]);
    }

    /**
     * Téléphone non vérifié (juste après inscription, avant OTP).
     */
    public function unverified(): static
    {
        return $this->state(fn (array $attributes) => [
            'phone_verified' => false,
        ]);
    }
}
