<?php

namespace Tests\Feature\Auth;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class StaffPasswordStrengthTest extends TestCase
{
    use RefreshDatabase;

    private function change(string $new): \Illuminate\Testing\TestResponse
    {
        return $this->putJson('/api/v1/auth/change-password', [
            'current_password' => 'StaffPass1',
            'new_password' => $new,
            'new_password_confirmation' => $new,
        ]);
    }

    public function test_staff_needs_a_long_password(): void
    {
        $admin = User::factory()->create(['role' => 'admin', 'password' => Hash::make('StaffPass1')]);
        Sanctum::actingAs($admin);

        $this->change('Abcdefgh1234')->assertStatus(422)->assertJsonValidationErrors(['new_password']);
        $this->change('Cheval-Pile-Lune-Riz-47')->assertOk();
    }

    public function test_regular_user_rule_is_unchanged(): void
    {
        $user = User::factory()->create(['role' => 'user', 'password' => Hash::make('StaffPass1')]);
        Sanctum::actingAs($user);

        $this->change('Abcdefg1')->assertOk();
    }
}
