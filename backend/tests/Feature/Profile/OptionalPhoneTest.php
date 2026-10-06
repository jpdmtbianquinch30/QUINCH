<?php

namespace Tests\Feature\Profile;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/** Le numéro de téléphone est facultatif : ajout, changement et suppression depuis le profil. */
class OptionalPhoneTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_add_a_phone_number(): void
    {
        $user = User::factory()->create(['phone_number' => null]);

        $this->actingAs($user, 'sanctum')
            ->putJson('/api/v1/user/phone', ['phone_number' => '+221771234567'])
            ->assertOk();

        $this->assertDatabaseHas('users', [
            'id' => $user->id,
            'phone_number' => '+221771234567',
            'phone_verified' => false,
        ]);
    }

    public function test_user_can_change_the_phone_number(): void
    {
        $user = User::factory()->create(['phone_number' => '+221771111111']);

        $this->actingAs($user, 'sanctum')
            ->putJson('/api/v1/user/phone', ['phone_number' => '+221772222222'])
            ->assertOk();

        $this->assertSame('+221772222222', $user->fresh()->phone_number);
    }

    public function test_user_can_remove_the_phone_number(): void
    {
        $user = User::factory()->create(['phone_number' => '+221771111111']);

        $this->actingAs($user, 'sanctum')
            ->putJson('/api/v1/user/phone', ['phone_number' => null])
            ->assertOk();

        $this->assertNull($user->fresh()->phone_number);
    }

    public function test_number_used_by_another_account_is_refused(): void
    {
        User::factory()->create(['phone_number' => '+221772222222']);
        $user = User::factory()->create(['phone_number' => null]);

        $this->actingAs($user, 'sanctum')
            ->putJson('/api/v1/user/phone', ['phone_number' => '+221772222222'])
            ->assertStatus(422)
            ->assertJsonPath('error', 'phone_taken');
    }

    public function test_bad_format_is_refused(): void
    {
        $user = User::factory()->create();

        $this->actingAs($user, 'sanctum')
            ->putJson('/api/v1/user/phone', ['phone_number' => '0771234567'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['phone_number']);
    }

    public function test_keeping_its_own_number_is_not_a_conflict(): void
    {
        $user = User::factory()->create(['phone_number' => '+221771111111']);

        $this->actingAs($user, 'sanctum')
            ->putJson('/api/v1/user/phone', ['phone_number' => '+221771111111'])
            ->assertOk();
    }

    public function test_old_phone_change_routes_are_gone(): void
    {
        $user = User::factory()->create();

        foreach (['phone/change', 'phone/request-change', 'phone/confirm-change'] as $route) {
            $this->actingAs($user, 'sanctum')
                ->postJson("/api/v1/user/{$route}", [])
                ->assertNotFound();
        }
    }

    public function test_unauthenticated_request_is_refused(): void
    {
        $this->putJson('/api/v1/user/phone', ['phone_number' => '+221771234567'])->assertUnauthorized();
    }
}
