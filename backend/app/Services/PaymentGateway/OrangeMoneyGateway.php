<?php

namespace App\Services\PaymentGateway;

class OrangeMoneyGateway implements PaymentGatewayInterface
{
    public function initiatePayment(array $request): array
    {
        // In production: API call to Orange Money Senegal
        return [
            'success' => true,
            'payment_url' => 'https://api.orange.com/orange-money-sn/v1/payment/' . uniqid(),
            'transaction_id' => 'OM-' . strtoupper(uniqid()),
            'gateway' => 'orange_money',
        ];
    }

    public function verifyPayment(string $transactionId): array
    {
        return [
            'verified' => true,
            'status' => 'completed',
            'transaction_id' => $transactionId,
        ];
    }

    public function refundPayment(string $transactionId, float $amount): array
    {
        return [
            'success' => true,
            'refund_id' => 'REF-' . strtoupper(uniqid()),
            'amount' => $amount,
        ];
    }

    public function getName(): string
    {
        return 'Orange Money';
    }

    public function getFeeRate(): float
    {
        return 0.025; // 2.5%
    }
}
