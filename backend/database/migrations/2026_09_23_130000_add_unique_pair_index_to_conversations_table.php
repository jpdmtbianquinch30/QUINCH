<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * Garantit "1 utilisateur = 1 conversation avec un autre utilisateur" au
     * niveau base, symétriquement (A->B et B->A = même paire). Index
     * d'expression Postgres : ni unique(buyer_id, seller_id) classique ni
     * Laravel seul ne savent exprimer une unicité symétrique sur 2 colonnes.
     *
     * IMPORTANT : avant de poser cette contrainte, on fusionne les doublons
     * qui existent deja en base (le bug FollowController — whereNull sur
     * product_id — en a probablement deja cree en usage reel). Sans cette
     * fusion prealable, CREATE UNIQUE INDEX echoue purement et simplement
     * des qu'une seule paire est dupliquee (teste en conditions reelles :
     * "could not create unique index ... is duplicated").
     */
    public function up(): void
    {
        $duplicateGroups = DB::select("
            SELECT LEAST(buyer_id::text, seller_id::text) AS lo,
                   GREATEST(buyer_id::text, seller_id::text) AS hi,
                   COUNT(*) AS cnt
            FROM conversations
            GROUP BY lo, hi
            HAVING COUNT(*) > 1
        ");

        foreach ($duplicateGroups as $group) {
            $rows = DB::table('conversations')
                ->whereRaw('LEAST(buyer_id::text, seller_id::text) = ?', [$group->lo])
                ->whereRaw('GREATEST(buyer_id::text, seller_id::text) = ?', [$group->hi])
                ->orderBy('created_at')
                ->get();

            $survivor = $rows->first();
            $duplicates = $rows->slice(1);

            foreach ($duplicates as $dup) {
                // Rattache les messages du doublon au survivant, dans l'ordre
                // chronologique global (pas de perte d'historique).
                DB::table('messages')->where('conversation_id', $dup->id)->update(['conversation_id' => $survivor->id]);
            }

            $latest = DB::table('messages')->where('conversation_id', $survivor->id)->max('created_at');
            DB::table('conversations')->where('id', $survivor->id)->update([
                'last_message_at' => $latest ?? $survivor->last_message_at,
                // Garde le product_id du survivant s'il en a un, sinon recupere
                // celui d'un doublon (au cas ou le doublon sans produit soit
                // arrive en premier chronologiquement).
                'product_id' => $survivor->product_id ?? $duplicates->firstWhere('product_id', '!=', null)?->product_id,
            ]);

            DB::table('conversations')->whereIn('id', $duplicates->pluck('id'))->delete();
        }

        DB::statement(
            'CREATE UNIQUE INDEX conversations_user_pair_unique
             ON conversations (LEAST(buyer_id::text, seller_id::text), GREATEST(buyer_id::text, seller_id::text))'
        );
    }

    public function down(): void
    {
        DB::statement('DROP INDEX IF EXISTS conversations_user_pair_unique');
    }
};
