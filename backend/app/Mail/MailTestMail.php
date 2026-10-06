<?php

namespace App\Mail;

use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;

/**
 * Message de test (php artisan quinch:mail-test) : valide le SMTP sans code OTP.
 */
class MailTestMail extends Mailable
{
    public function envelope(): Envelope
    {
        return new Envelope(subject: "QUINCH : test d'envoi d'e-mail");
    }

    public function content(): Content
    {
        return new Content(
            view: 'emails.mail-test',
            text: 'emails.mail-test-text',
        );
    }
}
