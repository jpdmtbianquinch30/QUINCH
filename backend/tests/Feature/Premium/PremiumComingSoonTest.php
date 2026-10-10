<?php

namespace Tests\Feature\Premium;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PremiumComingSoonTest extends TestCase
{
    use RefreshDatabase;

    public function test_subscription_is_refused_without_calling_wave_when_premium_is_coming_soon(): void
    {
        config(['quinch.premium.payments_enabled' => false]);
        Http::fake();

        Sanctum::actingAs(User::factory()->create(['email_verified_at' => now()]));
        $this->postJson('/api/v1/premium/subscribe', ['plan' => 'monthly', 'payment_method' => 'wave'])
            ->assertStatus(403)->assertJsonPath('error', 'premium_coming_soon');

        Http::assertNothingSent();
    }

    public function test_public_config_tells_the_frontend(): void
    {
        config(['quinch.premium.payments_enabled' => false]);
        $this->getJson('/api/v1/public-config')->assertOk()->assertJsonPath('premium_payments', false);
    }
}
