<?php

namespace App\Services;

use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Droit d'accès et de portabilité : réunit TOUTES les données personnelles d'un
 * utilisateur dans un seul document JSON.
 *
 * Choix de conception :
 *  - Les tables « annexes » sont décrites par une carte table => colonnes liées à
 *    l'utilisateur. Une table ou une colonne absente est ignorée (jamais d'erreur 500
 *    parce qu'une évolution du schéma n'a pas été répercutée ici).
 *  - Les messages exportés sont ceux ÉCRITS par l'utilisateur : les messages reçus
 *    contiennent des données personnelles de leur auteur, pas de la personne qui exporte.
 *  - Aucun secret (mot de passe, codes de vérification, jetons) n'est exporté.
 */
class UserDataExporter
{
    /** Plafond de lignes par table, pour qu'un export reste raisonnable en mémoire. */
    private const MAX_ROWS = 10000;

    /**
     * clé de l'export => [table, [colonnes qui désignent l'utilisateur]].
     *
     * @var array<string, array{0: string, 1: array<int, string>}>
     */
    private const RELATED = [
        'transactions'           => ['transactions', ['buyer_id', 'seller_id']],
        'conversations'          => ['conversations', ['buyer_id', 'seller_id']],
        'negotiations'           => ['negotiations', ['buyer_id', 'seller_id']],
        'reviews'                => ['user_reviews', ['reviewer_id', 'seller_id']],
        'favorite_collections'   => ['favorite_collections', ['user_id']],
        'favorite_items'         => ['favorite_items', ['user_id']],
        'liked_products'         => ['product_likes', ['user_id']],
        'saved_products'         => ['product_saves', ['user_id']],
        'shared_products'        => ['product_shares', ['user_id']],
        'follows'                => ['user_follows', ['follower_id', 'following_id']],
        'notifications'          => ['user_notifications', ['user_id']],
        'notification_settings'  => ['notification_preferences', ['user_id']],
        'support_tickets'        => ['support_tickets', ['user_id']],
        'reports_made'           => ['user_reports', ['reporter_id']],
        'product_reports_made'   => ['product_reports', ['reporter_id']],
        'premium_subscriptions'  => ['premium_subscriptions', ['user_id']],
        'badges'                 => ['user_badges', ['user_id']],
        'strikes'                => ['user_strikes', ['user_id']],
        'moderation_appeals'     => ['moderation_appeals', ['user_id']],
    ];

    /** @return array<string, mixed> */
    public function export(User $user): array
    {
        $data = [
            'exported_at' => now()->toIso8601String(),
            // Profil, y compris la preuve du consentement (terms_*, privacy_version)
            // et l'empreinte d'appareil. Mot de passe et codes restent masqués ($hidden).
            'profile'     => $user->makeVisible(['device_fingerprint'])->toArray(),
            'products'    => $user->products()->withTrashed()->limit(self::MAX_ROWS)->get()->toArray(),
            'videos'      => $user->videos()->limit(self::MAX_ROWS)->get()->toArray(),
        ];

        foreach (self::RELATED as $key => [$table, $columns]) {
            $data[$key] = $this->rows($table, $columns, $user->id);
        }

        $data['messages_sent'] = $this->messagesSent($user->id);

        return $data;
    }

    /**
     * @param  array<int, string>  $columns
     * @return array<int, array<string, mixed>>
     */
    private function rows(string $table, array $columns, string $userId): array
    {
        if (!Schema::hasTable($table)) {
            return [];
        }

        $columns = array_values(array_filter($columns, fn (string $c) => Schema::hasColumn($table, $c)));
        if ($columns === []) {
            return [];
        }

        $rows = DB::table($table)
            ->where(function ($query) use ($columns, $userId) {
                foreach ($columns as $i => $column) {
                    $i === 0 ? $query->where($column, $userId) : $query->orWhere($column, $userId);
                }
            })
            ->limit(self::MAX_ROWS)
            ->get();

        return $rows->map(fn ($row) => (array) $row)->all();
    }

    /** @return array<int, array<string, mixed>> */
    private function messagesSent(string $userId): array
    {
        if (!Schema::hasTable('messages') || !Schema::hasColumn('messages', 'sender_id')) {
            return [];
        }

        return DB::table('messages')
            ->where('sender_id', $userId)
            ->orderBy('created_at')
            ->limit(self::MAX_ROWS * 2)
            ->get(['id', 'conversation_id', 'body', 'type', 'metadata', 'created_at'])
            ->map(fn ($row) => (array) $row)
            ->all();
    }
}
