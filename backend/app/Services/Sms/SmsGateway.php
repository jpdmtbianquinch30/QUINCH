<?php

namespace App\Services\Sms;

interface SmsGateway
{
    /**
     * Envoie un SMS. $to au format international (+221XXXXXXXXX).
     * Doit lever une exception en cas d'échec (le job réessaiera).
     */
    public function send(string $to, string $message): void;
}
