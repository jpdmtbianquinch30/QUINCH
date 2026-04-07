<?php

namespace App\Services\PaymentGateway;

class WaveGateway implements PaymentGatewayInterface
{
    public function initiatePayment(array $request): array
    {
        return [
            'success' => true,
            'payment_url' => 'https://api.wave.com/v1/checkout/' . uniqid(),
            'transaction_id' => 'WV-' . strtoupper(uniqid()),
            'gateway' => 'wave',
        ];
    }

    public function verifyPayment(string $transactionId): array
    {
        return ['verified' => true, 'status' => 'completed', 'transaction_id' => $transactionId];
    }

    public function refundPayment(string $transactionId, float $amount): array
    {
        return ['success' => true, 'refund_id' => 'REF-' . strtoupper(uniqid()), 'amount' => $amount];
    }

    public function getName(): string { return 'Wave'; }
    public function getFeeRate(): float { return 0.01; } // 1%
}
