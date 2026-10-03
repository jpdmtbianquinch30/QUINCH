<?php

namespace App\Jobs;

use App\Services\Sms\SmsGateway;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldBeEncrypted;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Support\Facades\Log;

/**
 * Envoi d'un SMS en arrière-plan : l'API répond tout de suite, sans attendre
 * le fournisseur. ShouldBeEncrypted : le message (qui contient le code OTP)
 * est chiffré dans Redis et dans la table failed_jobs.
 */
class SendSmsJob implements ShouldQueue, ShouldBeEncrypted
{
    use Dispatchable, InteractsWithQueue, Queueable;

    public int $tries = 3;

    /** @var array<int, int> */
    public array $backoff = [5, 30];

    public int $timeout = 30;

    public function __construct(public string $to, public string $message) {}

    public function handle(SmsGateway $gateway): void
    {
        $gateway->send($this->to, $this->message);
    }

    public function failed(\Throwable $e): void
    {
        Log::error('SMS non envoyé après plusieurs tentatives', [
            'to'    => substr($this->to, 0, 6) . '***' . substr($this->to, -2),
            'error' => $e->getMessage(),
        ]);
    }
}
