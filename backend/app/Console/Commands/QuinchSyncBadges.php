<?php

namespace App\Console\Commands;

use App\Services\BadgeService;
use Illuminate\Console\Command;

class QuinchSyncBadges extends Command
{
    protected $signature = 'quinch:sync-badges';
    protected $description = 'Attribue / retire les badges automatiques selon leurs règles (Premium, KYC, ventes, ancienneté…).';

    public function handle(BadgeService $badges): int
    {
        foreach ($badges->sync() as $key => $r) {
            $this->line(sprintf('%-18s +%d  -%d', $key, $r['added'], $r['removed']));
        }

        return self::SUCCESS;
    }
}
