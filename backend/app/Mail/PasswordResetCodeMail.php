<?php

namespace App\Mail;

use Illuminate\Contracts\Queue\ShouldBeEncrypted;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * E-mail contenant le code de réinitialisation du mot de passe.
 *
 * - ShouldBeEncrypted : le message (qui contient le code en clair) est chiffré
 *   dans la file Redis et dans la table failed_jobs, comme l'était le SMS.
 * - tries / backoff / timeout : un SMTP qui répond mal ou lentement est réessayé
 *   (10 s puis 60 s) avant d'abandonner, au lieu de perdre le code au premier échec.
 * - Version texte brut en plus du HTML : les filtres anti-spam pénalisent les
 *   messages sans alternative texte.
 */
class PasswordResetCodeMail extends Mailable implements ShouldBeEncrypted
{
    /** Nombre total de tentatives d'envoi (1re + 2 reprises). */
    public int $tries = 3;

    /** @var array<int, int> secondes d'attente avant chaque reprise */
    public array $backoff = [10, 60];

    public int $timeout = 30;

    public function __construct(
        public string $code,
        public int $minutes = 10,
    ) {
    }

    public function envelope(): Envelope
    {
        return new Envelope(subject: 'QUINCH : votre code de réinitialisation');
    }

    public function content(): Content
    {
        return new Content(
            view: 'emails.password-reset-code',
            text: 'emails.password-reset-code-text',
        );
    }

    /** Appelé quand toutes les tentatives ont échoué (adresse masquée, code jamais journalisé). */
    public function failed(Throwable $e): void
    {
        $address = (string) ($this->to[0]['address'] ?? '');

        Log::error('E-mail de code non envoyé après plusieurs tentatives', [
            'to'    => self::mask($address),
            'error' => preg_replace('#https?://\S+#i', '[url]', $e->getMessage()),
        ]);
    }

    /** a***@domaine.com */
    public static function mask(string $email): string
    {
        $at = strrpos($email, '@');
        if ($at === false || $at < 1) {
            return '***';
        }

        return substr($email, 0, 1) . '***' . substr($email, $at);
    }
}
