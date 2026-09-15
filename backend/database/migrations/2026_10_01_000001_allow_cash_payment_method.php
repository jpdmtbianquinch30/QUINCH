<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Ajoute 'cash' (paiement en espèces à la livraison / au retrait) à la
 * liste des payment_method autorisés en base.
 *
 * ATTENTION au nommage : Laravel exécute les migrations dans l'ordre
 * ALPHABÉTIQUE des noms de fichiers. La migration qui pose la contrainte
 * restrictive s'appelle 2026_09_31_000001_restrict_payment_methods... (le
 * 31 septembre n'existe pas dans le calendrier, mais Laravel ne s'en sert
 * que comme chaîne de tri). Cette migration doit donc impérativement être
 * datée APRÈS, sinon la contrainte restrictive s'exécute en dernier et
 * écrase l'autorisation - 'cash' serait alors rejeté par Postgres avec une
 * erreur SQL générique à chaque achat en espèces.
 */
return new class extends Migration
{
    public function up(): void
    {
        DB::statement('ALTER TABLE transactions DROP CONSTRAINT IF EXISTS transactions_payment_method_check');
        DB::statement("ALTER TABLE transactions ADD CONSTRAINT transactions_payment_method_check CHECK (payment_method IN ('orange_money', 'wave', 'cash'))");
    }

    public function down(): void
    {
        DB::statement('ALTER TABLE transactions DROP CONSTRAINT IF EXISTS transactions_payment_method_check');
        DB::statement("ALTER TABLE transactions ADD CONSTRAINT transactions_payment_method_check CHECK (payment_method IN ('orange_money', 'wave'))");
    }
};
