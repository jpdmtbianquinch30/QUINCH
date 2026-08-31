<?php

namespace Tests\Feature\Profile;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class PhoneNumberChangeTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_request_a_phone_change_with_correct_password(): void
    {
        $user = User::factory()->create([
            'phone_number' => '+221771111111',
            'password' => Hash::make('CurrentPass1'),
        ]);

        $response = $this->actingAs($user, 'sanctum')->postJson('/api/v1/user/phone/request-change', [
            'new_phone_number' => '+221772222222',
            'current_password' => 'CurrentPass1',
        ]);

        $response->assertOk()->assertJsonStructure(['message', 'demo_otp']);
        $this->assertDatabaseHas('users', [
            'id' => $user->id,
            'phone_number' => '+221771111111', // inchangé tant que non confirmé
            'pending_phone_number' => '+221772222222',
        ]);
    }

    public function test_phone_change_request_fails_with_wrong_password(): void
    {
        $user = User::factory()->create(['password' => Hash::make('CurrentPass1')]);

        $response = $this->actingAs($user, 'sanctum')->postJson('/api/v1/user/phone/request-change', [
            'new_phone_number' => '+221772222222',
            'current_password' => 'WrongPassword1',
        ]);

        $response->assertUnprocessable()->assertJsonPath('error', 'invalid_password');
    }

    public function test_phone_change_request_fails_if_number_already_taken(): void
    {
        User::factory()->create(['phone_number' => '+221772222222']);
        $user = User::factory()->create(['password' => Hash::make('CurrentPass1')]);

        $response = $this->actingAs($user, 'sanctum')->postJson('/api/v1/user/phone/request-change', [
            'new_phone_number' => '+221772222222',
            'current_password' => 'CurrentPass1',
        ]);

        $response->assertUnprocessable()->assertJsonValidationErrors(['new_phone_number']);
    }

    public function test_confirming_with_correct_otp_updates_the_real_phone_number(): void
    {
        $user = User::factory()->create([
            'phone_number' => '+221771111111',
            'password' => Hash::make('CurrentPass1'),
        ]);

        $request = $this->actingAs($user, 'sanctum')->postJson('/api/v1/user/phone/request-change', [
            'new_phone_number' => '+221772222222',
            'current_password' => 'CurrentPass1',
        ]);
        $demoOtp = $request->json('demo_otp');

        $confirm = $this->actingAs($user, 'sanctum')->postJson('/api/v1/user/phone/confirm-change', [
            'otp' => $demoOtp,
        ]);

        $confirm->assertOk();
        $this->assertDatabaseHas('users', [
            'id' => $user->id,
            'phone_number' => '+221772222222',
            'pending_phone_number' => null,
        ]);
    }

    public function test_confirming_with_wrong_otp_fails_and_does_not_change_phone(): void
    {
        $user = User::factory()->create(['phone_number' => '+221771111111']);
        $user->pending_phone_number = '+221772222222';
        $user->save();
        $user->generateOtp();

        $response = $this->actingAs($user, 'sanctum')->postJson('/api/v1/user/phone/confirm-change', [
            'otp' => '000000',
        ]);

        $response->assertUnprocessable();
        $this->assertDatabaseHas('users', ['id' => $user->id, 'phone_number' => '+221771111111']);
    }
}
