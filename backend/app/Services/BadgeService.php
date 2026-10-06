<?php

namespace App\Services;

use App\Models\BadgeDefinition;
use App\Models\User;
use Illuminate\Support\Facades\DB;

/**
 * Attribution AUTOMATIQUE des badges.
 *
 * Pour chaque définition active ayant une `auto_rule`, on calcule l'ensemble des
 * utilisateurs qui remplissent la condition, puis :
 *   - on ajoute le badge à ceux qui le méritent et ne l'ont pas (source = 'auto') ;
 *   - on retire les badges `source = 'auto'` à ceux qui ne le méritent plus.
 * Les badges attribués À LA MAIN (source = 'manual') ne sont jamais retirés par le système.
 *
 * Tout est fait en requêtes ensemblistes (INSERT … SELECT / DELETE … NOT EXISTS) :
 * le coût ne dépend pas du nombre d'utilisateurs en PHP, seulement de la base.
 * syncAll() tourne chaque heure (commande `quinch:sync-badges`) ; syncUser() est
 * appelé immédiatement quand le statut Premium ou KYC d'un compte change.
 */
class BadgeService
{
    /** @return array{0:string,1:array} fragment SQL (alias "u" = users) + bindings, ou [null, []] si règle inconnue. */
    private function condition(string $rule, ?int $threshold): array
    {
        return match ($rule) {
            'premium' => ['u.is_premium = true AND u.premium_expires_at > NOW()', []],
            'kyc_verified' => ["u.kyc_status = 'verified'", []],
            'sales_completed' => [
                "(SELECT COUNT(*) FROM transactions t WHERE t.seller_id = u.id AND t.payment_status = 'completed') >= ?",
                [max(1, (int) $threshold)],
            ],
            'account_age_days' => ['u.created_at <= ?', [now()->subDays(max(1, (int) $threshold))]],
            // trust_score est stocké en 0..1 ; le seuil admin est en %.
            'trust_score' => ['u.trust_score >= ?', [max(0, min(100, (int) $threshold)) / 100]],
            default => [null, []],
        };
    }

    /** Synchronise tous les badges automatiques (ou un seul utilisateur). */
    public function sync(?string $onlyUserId = null): array
    {
        $report = [];

        foreach (BadgeDefinition::query()->whereNotNull('auto_rule')->get() as $def) {
            if (!$def->is_active) {
                // Badge désactivé : il n'est plus affiché ; les attributions restent en base
                // pour être retrouvées à la réactivation.
                continue;
            }

            [$cond, $bindings] = $this->condition($def->auto_rule, $def->auto_threshold);
            if ($cond === null) {
                continue;
            }

            $userFilter = $onlyUserId ? ' AND u.id = ?' : '';
            $userBind = $onlyUserId ? [$onlyUserId] : [];
            $base = "u.account_status = 'active' AND u.anonymized_at IS NULL AND ({$cond}){$userFilter}";

            $added = DB::affectingStatement(
                "INSERT INTO user_badges (id, user_id, badge_type, source, created_at, updated_at)
                 SELECT gen_random_uuid(), u.id, ?, 'auto', NOW(), NOW()
                 FROM users u
                 WHERE {$base}
                   AND NOT EXISTS (SELECT 1 FROM user_badges b WHERE b.user_id = u.id AND b.badge_type = ?)",
                array_merge([$def->key], $bindings, $userBind, [$def->key])
            );

            $removeUser = $onlyUserId ? ' AND ub.user_id = ?' : '';
            $removed = DB::affectingStatement(
                "DELETE FROM user_badges ub
                 WHERE ub.badge_type = ? AND ub.source = 'auto'{$removeUser}
                   AND NOT EXISTS (SELECT 1 FROM users u WHERE u.id = ub.user_id AND {$base})",
                array_merge([$def->key], $onlyUserId ? [$onlyUserId] : [], $bindings, $userBind)
            );

            $report[$def->key] = ['added' => $added, 'removed' => $removed];
        }

        return $report;
    }

    /** Appel « best effort » : un souci de badge ne doit jamais casser l'action métier. */
    public function syncUserSafe(User $user): void
    {
        try {
            $this->sync($user->id);
        } catch (\Throwable $e) {
            logger()->warning('Synchronisation des badges échouée : ' . $e->getMessage());
        }
    }

    /** Supprime les attributions automatiques d'un badge (règle retirée / modifiée). */
    public function purgeAuto(string $key): int
    {
        return DB::table('user_badges')->where('badge_type', $key)->where('source', 'auto')->delete();
    }
}
