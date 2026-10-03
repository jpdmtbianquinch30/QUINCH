<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * La contrainte products_status_check n'acceptait que 5 statuts, alors que
 * l'API et le modèle utilisent aussi "paused" (annonce mise en pause par son
 * propriétaire) et "disabled" (annonce retirée par la modération).
 * Sans cette migration, ces statuts provoquaient une erreur 500.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (DB::getDriverName() !== 'pgsql') {
            return;
        }

        DB::statement('ALTER TABLE products DROP CONSTRAINT IF EXISTS products_status_check');
        DB::statement(
            "ALTER TABLE products ADD CONSTRAINT products_status_check
             CHECK (status IN ('draft', 'active', 'sold', 'reserved', 'expired', 'paused', 'disabled'))"
        );
    }

    public function down(): void
    {
        if (DB::getDriverName() !== 'pgsql') {
            return;
        }

        // On ramène les lignes aux anciens statuts avant de restaurer l'ancienne contrainte.
        DB::statement("UPDATE products SET status = 'draft' WHERE status = 'paused'");
        DB::statement("UPDATE products SET status = 'expired' WHERE status = 'disabled'");

        DB::statement('ALTER TABLE products DROP CONSTRAINT IF EXISTS products_status_check');
        DB::statement(
            "ALTER TABLE products ADD CONSTRAINT products_status_check
             CHECK (status IN ('draft', 'active', 'sold', 'reserved', 'expired'))"
        );
    }
};
