<?php

namespace App\Services\PaymentGateway;

class FreeMoneyGateway implements PaymentGatewayInterface
{
    public function initiatePayment(array $request): array
    {
        return [
            'success' => true,
            'payment_url' => 'https://api.free.sn/money/v1/pay/' . uniqid(),
            'transaction_id' => 'FM-' . strtoupper(uniqid()),
            'gateway' => 'free_money',
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

    public function getName(): string { return 'Free Money'; }
    public function getFeeRate(): float { return 0.02; }
}
