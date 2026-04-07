<?php

namespace App\Services\PaymentGateway;

interface PaymentGatewayInterface
{
    public function initiatePayment(array $request): array;
    public function verifyPayment(string $transactionId): array;
    public function refundPayment(string $transactionId, float $amount): array;
    public function getName(): string;
    public function getFeeRate(): float;
}
