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
     */
    public function up(): void
    {
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
