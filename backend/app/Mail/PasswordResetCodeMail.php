<?php

namespace App\Mail;

use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;

/** E-mail contenant le code de réinitialisation du mot de passe. */
class PasswordResetCodeMail extends Mailable
{
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
        return new Content(view: 'emails.password-reset-code');
    }
}
