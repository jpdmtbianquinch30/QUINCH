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
            'cash' => new CashGateway(),
            default => throw new InvalidArgumentException("Passerelle non supportée: {$gateway}"),
        };
    }

    public static function getAvailableGateways(): array
    {
        return [
            ['id' => 'orange_money', 'name' => 'Orange Money', 'icon' => 'orange_money', 'fee_rate' => 0.025],
            ['id' => 'wave', 'name' => 'Wave', 'icon' => 'wave', 'fee_rate' => 0.01],
            // Pas de commission : aucune passerelle n'intervient, l'argent
            // passe directement de la main à la main.
            ['id' => 'cash', 'name' => 'Espèces', 'icon' => 'payments', 'fee_rate' => 0.0],
        ];
    }
}
