<?php

namespace App\Rules;

use App\Models\User;
use Closure;
use Illuminate\Contracts\Validation\ValidationRule;

/**
 * Nom d'utilisateur public : format, unicité INSENSIBLE À LA CASSE (« Admin » = « admin »)
 * et noms réservés (usurpation de l'équipe : « QUINCH_Support », « admin »...).
 */
class AvailableUsername implements ValidationRule
{
    /** Noms interdits tels quels (comparés en minuscules, sans « _ »). */
    private const RESERVED = [
        'admin', 'administrator', 'administrateur', 'root', 'support', 'moderator', 'moderateur',
        'moderation', 'staff', 'system', 'systeme', 'help', 'aide', 'contact', 'security', 'securite',
        'official', 'officiel', 'equipe', 'team', 'service', 'api', 'null', 'undefined', 'anonymous',
        'anonyme', 'wave', 'orangemoney', 'sonatel', 'cdp',
    ];

    public function __construct(private ?string $ignoreUserId = null) {}

    public function validate(string $attribute, mixed $value, Closure $fail): void
    {
        $value = (string) $value;

        if (!preg_match('/^[a-zA-Z0-9_]{3,30}$/', $value)) {
            $fail('Lettres, chiffres et _ uniquement (3 à 30 caractères).');

            return;
        }

        $normalized = str_replace('_', '', mb_strtolower($value));

        if (in_array($normalized, self::RESERVED, true) || str_contains($normalized, 'quinch')) {
            $fail("Ce nom d'utilisateur est réservé.");

            return;
        }

        $taken = User::whereRaw('lower(username) = ?', [mb_strtolower($value)])
            ->when($this->ignoreUserId, fn ($q) => $q->where('id', '!=', $this->ignoreUserId))
            ->exists();

        if ($taken) {
            $fail("Ce nom d'utilisateur est déjà pris.");
        }
    }
}
