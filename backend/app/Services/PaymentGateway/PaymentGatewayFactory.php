<?php

namespace App\Services\PaymentGateway;

use InvalidArgumentException;

class PaymentGatewayFactory
{
    public static function create(string $gateway): PaymentGatewayInterface
    {
        return match ($gateway) {
            'orange_money' => new OrangeMoneyGateway(),
            'wave' => new WaveGateway(),
            default => throw new InvalidArgumentException("Passerelle non supportée: {$gateway}"),
        };
    }

    public static function getAvailableGateways(): array
    {
        return [
            ['id' => 'orange_money', 'name' => 'Orange Money', 'icon' => 'orange_money', 'fee_rate' => 0.025],
            ['id' => 'wave', 'name' => 'Wave', 'icon' => 'wave', 'fee_rate' => 0.01],
        ];
    }
}