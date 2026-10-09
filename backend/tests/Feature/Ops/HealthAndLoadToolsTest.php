<?php

namespace Tests\Feature\Ops;

use App\Models\User;
use App\Support\HealthChecker;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

/**
 * Phase 6 : point de santé pour la supervision, comptes de test pour k6.
 */
class HealthAndLoadToolsTest extends TestCase
{
    use RefreshDatabase;

    // ─── GET /api/v1/ops/health ──────────────────────────────────────────────

    public function test_health_is_hidden_when_no_token_is_configured(): void
    {
        config(['ops.health_token' => null]);

        $this->getJson('/api/v1/ops/health')->assertNotFound();
        $this->getJson('/api/v1/ops/health', ['X-Health-Token' => ''])->assertNotFound();
    }

    public function test_health_is_hidden_with_a_wrong_token(): void
    {
        config(['ops.health_token' => 'secret-de-supervision-123']);

        $this->getJson('/api/v1/ops/health', ['X-Health-Token' => 'mauvais'])->assertNotFound();
        $this->getJson('/api/v1/ops/health')->assertNotFound();
    }

    public function test_health_reports_the_state_with_the_right_token(): void
    {
        config(['ops.health_token' => 'secret-de-supervision-123']);
        Cache::put(HealthChecker::SCHEDULER_KEY, now()->timestamp, 600);

        $this->getJson('/api/v1/ops/health', ['X-Health-Token' => 'secret-de-supervision-123'])
            ->assertOk()
            ->assertJsonPath('checks.database.status', 'ok')
            ->assertJsonPath('checks.scheduler.status', 'ok')
            ->assertJsonStructure(['status', 'time', 'checks' => ['database', 'cache', 'queue', 'scheduler', 'disk']]);
    }

    public function test_a_stopped_scheduler_is_reported_as_degraded_not_down(): void
    {
        config(['ops.health_token' => 'secret-de-supervision-123']);
        Cache::forget(HealthChecker::SCHEDULER_KEY);

        $this->getJson('/api/v1/ops/health', ['X-Health-Token' => 'secret-de-supervision-123'])
            ->assertOk()
            ->assertJsonPath('checks.scheduler.status', 'degraded')
            ->assertJsonPath('status', 'degraded');
    }

    public function test_deep_health_checks_the_media_storage(): void
    {
        Storage::fake('public');
        config(['ops.health_token' => 'secret-de-supervision-123']);

        $this->getJson('/api/v1/ops/health?deep=1', ['X-Health-Token' => 'secret-de-supervision-123'])
            ->assertOk()
            ->assertJsonPath('checks.media.status', 'ok');
    }

    public function test_health_command_succeeds_when_the_database_is_up(): void
    {
        $this->artisan('quinch:health')->assertExitCode(0);
    }

    // ─── quinch:seed-load-users ──────────────────────────────────────────────

    public function test_load_users_are_refused_unless_explicitly_allowed(): void
    {
        config(['ops.allow_load_test_data' => false]);

        $this->artisan('quinch:seed-load-users', ['count' => 3])->assertExitCode(1);

        $this->assertDatabaseMissing('users', ['email' => 'loadtest1@quinch.example']);
    }

    public function test_load_users_are_created_idempotently_with_tokens(): void
    {
        config(['ops.allow_load_test_data' => true]);

        $this->artisan('quinch:seed-load-users', ['count' => 3])->assertExitCode(0);
        $this->artisan('quinch:seed-load-users', ['count' => 3])->assertExitCode(0);

        $this->assertSame(3, User::where('email', 'like', 'loadtest%@quinch.example')->count());
        $user = User::where('email', 'loadtest1@quinch.example')->firstOrFail();
        $this->assertNotNull($user->email_verified_at);
        $this->assertSame(2, $user->tokens()->count(), 'Un nouveau jeton par exécution.');
    }

    public function test_load_users_can_be_purged(): void
    {
        config(['ops.allow_load_test_data' => true]);

        $this->artisan('quinch:seed-load-users', ['count' => 2])->assertExitCode(0);
        $this->artisan('quinch:seed-load-users', ['--purge' => true])->assertExitCode(0);

        $this->assertSame(0, User::where('email', 'like', 'loadtest%@quinch.example')->count());
    }
}
