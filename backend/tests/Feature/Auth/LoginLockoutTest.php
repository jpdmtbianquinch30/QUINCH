<?php

namespace Tests\Feature\Auth;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Routing\Middleware\ThrottleRequests;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class LoginLockoutTest extends TestCase
{
    use RefreshDatabase;

    private function attempt(string $phone, string $password)
    {
        return $this->postJson('/api/v1/auth/login', [
            'phone_number' => $phone,
            'password' => $password,
        ]);
    }

    public function test_login_is_locked_after_five_failures_even_with_the_right_password(): void
    {
        $this->withoutMiddleware(ThrottleRequests::class);

        User::factory()->create([
            'phone_number' => '+221771234567',
            'password' => Hash::make('Password1'),
        ]);

        for ($i = 0; $i < 5; $i++) {
            $this->attempt('+221771234567', 'Mauvais1')->assertStatus(422);
        }

        $this->attempt('+221771234567', 'Password1')->assertStatus(429);
    }

    public function test_unknown_numbers_are_locked_the_same_way(): void
    {
        $this->withoutMiddleware(ThrottleRequests::class);

        for ($i = 0; $i < 5; $i++) {
            $this->attempt('+221700000009', 'Mauvais1')->assertStatus(422);
        }

        $this->attempt('+221700000009', 'Mauvais1')->assertStatus(429);
    }

    public function test_another_phone_is_not_affected(): void
    {
        $this->withoutMiddleware(ThrottleRequests::class);

        User::factory()->create(['phone_number' => '+221771111111', 'password' => Hash::make('Password1')]);
        User::factory()->create(['phone_number' => '+221772222222', 'password' => Hash::make('Password1')]);

        for ($i = 0; $i < 5; $i++) {
            $this->attempt('+221771111111', 'Mauvais1')->assertStatus(422);
        }

        $this->attempt('+221772222222', 'Password1')->assertOk();
    }
}
