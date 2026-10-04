<?php

namespace App\Http\Controllers\Concerns;

use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

trait AdminHelpers
{
    /**
     * Hiérarchie des rôles : renvoie une réponse 403 si $request->user() n'a
     * pas le droit d'agir sur $target (soi-même ou rôle égal / supérieur).
     */
    protected function denyIfCannotManage(Request $request, User $target): ?JsonResponse
    {
        $actor = $request->user();

        if ($actor->id === $target->id) {
            return response()->json([
                'message' => 'Vous ne pouvez pas effectuer cette action sur votre propre compte.',
                'error' => 'cannot_manage_self',
            ], 403);
        }

        if (!$actor->canManage($target)) {
            return response()->json([
                'message' => "Vous ne pouvez agir que sur un rôle inférieur au vôtre.",
                'error' => 'role_hierarchy',
            ], 403);
        }

        return null;
    }

    /** Motif obligatoire (3 à 500 caractères) : réutilisé par toutes les actions de sanction. */
    protected function reasonRules(bool $required = true): array
    {
        return [$required ? 'required' : 'nullable', 'string', 'min:3', 'max:500'];
    }

    /** Recherche ILIKE sûre (échappe % et _), via Controller::likeTerm(). */
    protected function ilike($query, array $columns, string $term, array $castColumns = [])
    {
        $like = $this->likeTerm($term);

        return $query->where(function ($q) use ($columns, $castColumns, $like) {
            foreach ($columns as $col) {
                $q->orWhere($col, 'ILIKE', $like);
            }
            foreach ($castColumns as $col) {
                $q->orWhereRaw("{$col}::text ILIKE ?", [$like]);
            }
        });
    }
}
