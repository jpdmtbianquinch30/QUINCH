<?php

namespace Tests\Feature\Auth;

use App\Mail\MailTestMail;
use App\Mail\PasswordResetCodeMail;
use App\Models\User;
use Illuminate\Contracts\Queue\ShouldBeEncrypted;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Mail;
use Tests\TestCase;

/**
 * Fiabilité de la réception des codes par e-mail : chiffrement dans la file,
 * reprises, version texte, limites d'envoi, panne de file, commande de test SMTP.
 */
class OtpEmailDeliveryTest extends TestCase
{
    use RefreshDatabase;

    private const GENERIC = 'Si cette adresse est associée à un compte, un code a été envoyé par e-mail.';

    public function test_the_code_mail_is_encrypted_in_the_queue_and_retried(): void
    {
        $mail = new PasswordResetCodeMail('482915', 10);

        $this->assertInstanceOf(ShouldBeEncrypted::class, $mail);
        $this->assertSame(3, $mail->tries);
        $this->assertSame([10, 60], $mail->backoff);
    }

    public function test_the_mail_has_a_plain_text_alternative_with_the_code(): void
    {
        $mail = new PasswordResetCodeMail('482915', 10);

        $mail->assertSeeInHtml('482915');
        $mail->assertSeeInText('482915');
        $mail->assertSeeInText('10 minutes');
    }

    public function test_the_recipient_is_masked_in_logs(): void
    {
        $this->assertSame('f***@example.com', PasswordResetCodeMail::mask('fatou@example.com'));
        $this->assertSame('***', PasswordResetCodeMail::mask('pas-une-adresse'));
    }

    public function test_a_second_request_within_the_cooldown_is_rejected_with_retry_after(): void
    {
        Mail::fake();
        User::factory()->create(['email' => 'fatou@example.com']);

        $this->postJson('/api/v1/auth/forgot-password', ['email' => 'fatou@example.com'])->assertOk();

        $this->postJson('/api/v1/auth/forgot-password', ['email' => 'fatou@example.com'])
            ->assertStatus(429)
            ->assertJsonPath('error', 'otp_rate_limited')
            ->assertHeader('Retry-After');

        Mail::assertQueued(PasswordResetCodeMail::class, 1);
    }

    public function test_a_mail_queue_failure_does_not_change_the_response(): void
    {
        // Une panne de file ne doit ni renvoyer une erreur 500 ni révéler que le compte existe.
        User::factory()->create(['email' => 'fatou@example.com']);
        Mail::shouldReceive('to')->andThrow(new \RuntimeException('queue down'));

        $this->postJson('/api/v1/auth/forgot-password', ['email' => 'fatou@example.com'])
            ->assertOk()
            ->assertJsonPath('message', self::GENERIC);
    }

    public function test_mail_test_command_sends_a_message_to_the_given_address(): void
    {
        Mail::fake();

        $this->artisan('quinch:mail-test', ['email' => 'Test@Example.com'])->assertExitCode(0);

        Mail::assertSent(MailTestMail::class, fn (MailTestMail $m) => $m->hasTo('test@example.com'));
    }

    public function test_mail_test_command_can_go_through_the_queue(): void
    {
        Mail::fake();

        $this->artisan('quinch:mail-test', ['email' => 'test@example.com', '--queue' => true])->assertExitCode(0);

        Mail::assertQueued(MailTestMail::class);
    }

    public function test_mail_test_command_rejects_an_invalid_address(): void
    {
        Mail::fake();

        $this->artisan('quinch:mail-test', ['email' => 'pas-une-adresse'])->assertExitCode(1);

        Mail::assertNothingSent();
        Mail::assertNothingQueued();
    }

    public function test_mail_test_command_warns_when_the_mailer_does_not_really_send(): void
    {
        Mail::fake();
        config(['mail.default' => 'log']);

        $this->artisan('quinch:mail-test', ['email' => 'test@example.com'])
            ->expectsOutputToContain('MAIL_MAILER=log')
            ->assertExitCode(0);
    }
}
