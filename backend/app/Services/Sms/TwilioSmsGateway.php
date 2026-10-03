<?php

namespace App\Services\Sms;

use Illuminate\Support\Facades\Http;

class TwilioSmsGateway implements SmsGateway
{
    public function send(string $to, string $message): void
    {
        $cfg = (array) config('services.sms.twilio');

        if (empty($cfg['sid']) || empty($cfg['token']) || (empty($cfg['from']) && empty($cfg['messaging_service_sid']))) {
            throw new \RuntimeException('Twilio non configuré (TWILIO_SID / TOKEN / FROM).');
        }

        $payload = ['To' => $to, 'Body' => $message];

        if (!empty($cfg['messaging_service_sid'])) {
            $payload['MessagingServiceSid'] = $cfg['messaging_service_sid'];
        } else {
            $payload['From'] = $cfg['from'];
        }

        $response = Http::asForm()
            ->withBasicAuth($cfg['sid'], $cfg['token'])
            ->timeout(10)
            ->post("https://api.twilio.com/2010-04-01/Accounts/{$cfg['sid']}/Messages.json", $payload);

        if (!$response->successful()) {
            throw new \RuntimeException(
                'Twilio a répondu HTTP ' . $response->status() . ' (code ' . $response->json('code') . ')'
            );
        }
    }
}
