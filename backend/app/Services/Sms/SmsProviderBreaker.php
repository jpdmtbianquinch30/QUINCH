<?php

namespace App\Services\Sms;

/**
 * Disjoncteur par fournisseur SMS : après un échec, le fournisseur est mis de
 * côté quelques instants pour que les envois suivants passent directement par
 * le fournisseur de secours (sans attendre un timeout de 10 s à chaque SMS).
 */
interface SmsProviderBreaker
{
    public function isOpen(string $provider): bool;

    public function trip(string $provider): void;

    public function clear(string $provider): void;
}
