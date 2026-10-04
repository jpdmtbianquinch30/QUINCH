<?php

namespace App\Console\Commands;

use App\Models\User;
use App\Services\Admin\AdminLogger;
use Illuminate\Console\Command;

/**
 * Attribue un rôle depuis le serveur (seul moyen de créer un super_admin) :
 *   php artisan quinch:set-role +221771234567 super_admin
 */
class QuinchSetRole extends Command
{
    protected $signature = 'quinch:set-role {identifier : numéro de téléphone, email ou username} {role : user|moderator|admin|super_admin}';

    protected $description = 'Attribue un rôle (user, moderator, admin, super_admin) à un compte existant.';

    public function handle(): int
    {
        $role = $this->argument('role');
        if (!in_array($role, ['user', 'moderator', 'admin', 'super_admin'], true)) {
            $this->error('Rôle invalide.');

            return self::FAILURE;
        }

        $id = $this->argument('identifier');
        $user = User::where('phone_number', $id)->orWhere('email', $id)->orWhere('username', $id)->first();

        if (!$user) {
            $this->error("Aucun compte trouvé pour « {$id} ».");

            return self::FAILURE;
        }

        $old = $user->role;
        $user->forceFill(['role' => $role])->save();
        $user->tokens()->delete();

        AdminLogger::log(null, 'role_changed_cli', 'User', $user->id, ['from' => $old, 'to' => $role], 'critical');

        $this->info("{$user->full_name} : {$old} → {$role} (sessions révoquées).");

        return self::SUCCESS;
    }
}
