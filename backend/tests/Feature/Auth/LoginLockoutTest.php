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

    private function attempt(string $email, string $password)
    {
        return $this->postJson('/api/v1/auth/login', [
            'email' => $email,
            'password' => $password,
        ]);
    }

    public function test_login_is_locked_after_five_failures_even_with_the_right_password(): void
    {
        $this->withoutMiddleware(ThrottleRequests::class);

        User::factory()->create([
            'email' => 'fatou@example.com',
            'password' => Hash::make('Password1'),
        ]);

        for ($i = 0; $i < 5; $i++) {
            $this->attempt('fatou@example.com', 'Mauvais1')->assertStatus(422);
        }

        $this->attempt('fatou@example.com', 'Password1')->assertStatus(429);
    }

    public function test_unknown_emails_are_locked_the_same_way(): void
    {
        $this->withoutMiddleware(ThrottleRequests::class);

        for ($i = 0; $i < 5; $i++) {
            $this->attempt('personne@example.com', 'Mauvais1')->assertStatus(422);
        }

        $this->attempt('personne@example.com', 'Mauvais1')->assertStatus(429);
    }

    public function test_changing_the_letter_case_does_not_bypass_the_lockout(): void
    {
        $this->withoutMiddleware(ThrottleRequests::class);

        for ($i = 0; $i < 5; $i++) {
            $this->attempt('personne@example.com', 'Mauvais1')->assertStatus(422);
        }

        $this->attempt('PERSONNE@Example.com', 'Mauvais1')->assertStatus(429);
    }

    public function test_another_email_is_not_affected(): void
    {
        $this->withoutMiddleware(ThrottleRequests::class);

        User::factory()->create(['email' => 'un@example.com', 'password' => Hash::make('Password1')]);
        User::factory()->create(['email' => 'deux@example.com', 'password' => Hash::make('Password1')]);

        for ($i = 0; $i < 5; $i++) {
            $this->attempt('un@example.com', 'Mauvais1')->assertStatus(422);
        }

        $this->attempt('deux@example.com', 'Password1')->assertOk();
    }
}
