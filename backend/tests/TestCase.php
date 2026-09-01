<?php

namespace Tests;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Foundation\Testing\TestCase as BaseTestCase;

abstract class TestCase extends BaseTestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        // Les factories de test (User::factory()->admin(), ->suspended()...)
        // assignent délibérément des champs privilégiés (role, account_status)
        // pour construire des scénarios précis. Ce sont des données de test
        // entièrement contrôlées, pas une entrée HTTP non fiable : on lève
        // donc le guard de mass assignment ici, uniquement pour la durée des
        // tests. Cela n'a aucun effet en production (ce code n'est jamais
        // chargé en dehors de PHPUnit).
        Model::unguard();
    }
}
