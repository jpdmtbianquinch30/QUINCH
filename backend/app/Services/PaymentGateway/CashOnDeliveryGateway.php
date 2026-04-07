<?php

namespace App\Services\PaymentGateway;

class CashOnDeliveryGateway implements PaymentGatewayInterface
{
    public function initiatePayment(array $request): array
    {
        return [
            'success' => true,
            'payment_url' => null,
            'transaction_id' => 'COD-' . strtoupper(uniqid()),
            'gateway' => 'cash_delivery',
        ];
    }

    public function verifyPayment(string $transactionId): array
    {
        return ['verified' => true, 'status' => 'pending_delivery', 'transaction_id' => $transactionId];
    }

    public function refundPayment(string $transactionId, float $amount): array
    {
        return ['success' => false, 'message' => 'Remboursement non applicable pour paiement à la livraison.'];
    }

    public function getName(): string { return 'Paiement à la livraison'; }
    public function getFeeRate(): float { return 0; }
}
