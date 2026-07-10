<?php

namespace Tests\Unit;

use App\Models\User;
use Tests\TestCase;

/**
 * Vrai test unitaire : logique pure, aucune connexion DB nécessaire
 * (contrairement aux tests Feature qui utilisent RefreshDatabase).
 */
class UserSuspensionTest extends TestCase
{
    public function test_active_user_is_not_suspended(): void
    {
        $user = new User(['account_status' => 'active']);

        $this->assertFalse($user->isSuspended());
    }

    public function test_suspended_user_is_suspended(): void
    {
        $user = new User(['account_status' => 'suspended']);

        $this->assertTrue($user->isSuspended());
    }
}
