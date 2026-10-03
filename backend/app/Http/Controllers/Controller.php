<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;

abstract class Controller
{
    /**
     * Taille de page demandée par le client, bornée.
     * Valeur absente, non numérique ou < 1 : $default. Valeur > $max : $max.
     */
    protected function perPage(Request $request, int $default = 20, int $max = 50): int
    {
        $value = $request->query('per_page', $request->input('per_page'));

        if (!is_numeric($value)) {
            return $default;
        }

        $value = (int) $value;

        return $value < 1 ? $default : min($value, $max);
    }

    /**
     * Motif ILIKE sûr : échappe les % et _ saisis par l'utilisateur
     * (sinon une recherche "100%" ou "a_b" se comporte comme un joker).
     */
    protected function likeTerm(string $q): string
    {
        return '%' . str_replace(['\\', '%', '_'], ['\\\\', '\\%', '\\_'], trim($q)) . '%';
    }
}
