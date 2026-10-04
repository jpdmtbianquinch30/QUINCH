<?php

namespace App\Jobs;

use App\Services\Admin\FraudScanService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;

class RunFraudScan implements ShouldQueue
{
    use Dispatchable, Queueable;

    public function handle(FraudScanService $scan): void
    {
        $scan->run();
    }
}
