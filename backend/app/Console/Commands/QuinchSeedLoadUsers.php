<?php

namespace App\Console\Commands;

use App\Models\User;
use Illuminate\Console\Command;
use Throwable;

/**
 * Crée de faux comptes pour les tests de charge k6 (voir docs/LOAD-TESTING.md).
 *
 *   php artisan quinch:seed-load-users 100 --json > load-tests/tokens.json
 *   php artisan quinch:seed-load-users --purge
 *
 * Réservé à la PRÉPRODUCTION : refuse de s'exécuter sans QUINCH_ALLOW_LOADTEST_DATA=true.
 * Idempotent : un compte déjà créé est réutilisé (nouveau jeton, mot de passe inchangé).
 */
class QuinchSeedLoadUsers extends Command
{
    protected $signature = 'quinch:seed-load-users
        {count=50 : Nombre de comptes}
        {--prefix=loadtest : Préfixe des e-mails (loadtest1@quinch.example...)}
        {--password=LoadTest2026!x : Mot de passe des comptes de test}
        {--json : Affiche uniquement les jetons d\'API (JSON), pour k6}
        {--purge : Supprime les comptes de test existants}';

    protected $description = 'Crée des comptes de test pour les tests de charge (préproduction uniquement)';

    public function handle(): int
    {
        if (!config('ops.allow_load_test_data')) {
            $this->error('Refusé : QUINCH_ALLOW_LOADTEST_DATA n\'est pas activé. Cette commande est réservée à la préproduction.');

            return self::FAILURE;
        }

        $prefix = preg_replace('/[^a-z0-9]/i', '', (string) $this->option('prefix')) ?: 'loadtest';
        $json   = (bool) $this->option('json');

        if ($this->option('purge')) {
            return $this->purge($prefix);
        }

        $count = max(1, min(1000, (int) $this->argument('count')));
        $tokens = [];

        for ($i = 1; $i <= $count; $i++) {
            $email = "{$prefix}{$i}@quinch.example";

            $user = User::where('email', $email)->first();

            if (!$user) {
                $user = new User();
                $user->forceFill([
                    'full_name'         => "Test Charge {$i}",
                    'username'          => "{$prefix}_{$i}",
                    'email'             => $email,
                    'password'          => (string) $this->option('password'),
                    'email_verified_at' => now(),
                ])->save();
            }

            $tokens[] = [
                'email'    => $email,
                'username' => $user->username,
                'token'    => $user->createToken('loadtest')->plainTextToken,
            ];
        }

        if ($json) {
            $this->line((string) json_encode($tokens));

            return self::SUCCESS;
        }

        $this->info("{$count} compte(s) de test prêt(s) ({$prefix}1@quinch.example ...). Mot de passe : " . $this->option('password'));
        $this->line('Jetons pour k6 : php artisan quinch:seed-load-users ' . $count . ' --json > load-tests/tokens.json');

        return self::SUCCESS;
    }

    private function purge(string $prefix): int
    {
        $deleted = 0;

        foreach (User::where('email', 'like', $prefix . '%@quinch.example')->get() as $user) {
            try {
                $user->tokens()->delete();
                $user->delete();
                $deleted++;
            } catch (Throwable $e) {
                $this->warn("Compte {$user->email} conservé : {$e->getMessage()}");
            }
        }

        $this->info("{$deleted} compte(s) de test supprimé(s).");

        return self::SUCCESS;
    }
}
