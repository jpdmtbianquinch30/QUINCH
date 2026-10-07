<?php

namespace App\Support;

/**
 * Protection contre l'injection de formules dans les exports CSV (OWASP A03).
 *
 * Un champ saisi par un utilisateur (nom, titre d'annonce...) qui commence par
 * « = », « + », « - » ou « @ » est exécuté comme une formule quand un admin
 * ouvre l'export dans Excel ou LibreOffice (exfiltration de données, lancement
 * de commandes). On préfixe ces cellules d'une apostrophe : elles s'affichent
 * telles quelles et ne sont plus interprétées.
 */
final class CsvSafe
{
    private const DANGEROUS_START = ['=', '+', '-', '@', "\t", "\r"];

    public static function cell(mixed $value): mixed
    {
        if (!is_string($value) || $value === '') {
            return $value;
        }

        return in_array($value[0], self::DANGEROUS_START, true) ? "'" . $value : $value;
    }

    /**
     * @param  array<int, mixed>  $cells
     * @return array<int, mixed>
     */
    public static function row(array $cells): array
    {
        return array_map([self::class, 'cell'], $cells);
    }
}
