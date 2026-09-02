<?php

namespace App\Jobs;

use App\Models\PremiumSubscription;
use App\Models\User;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Support\Facades\DB;

class ExpirePremiumSubscriptions implements ShouldQueue
{
    use Dispatchable, Queueable;

    public function handle(): void
    {
        DB::transaction(function () {
            $expiredUsers = User::where('is_premium', true)
                ->where('premium_expires_at', '<', now())
                ->lockForUpdate()
                ->get();

            foreach ($expiredUsers as $user) {
                $user->forceFill([
                    'is_premium' => false,
                    'premium_plan' => null,
                ])->save();

                // On ne touche pas à premium_expires_at : on garde une trace
                // de la dernière date d'expiration pour l'historique/support.
                PremiumSubscription::where('user_id', $user->id)
                    ->where('status', 'active')
                    ->update(['status' => 'expired']);
            }
        });
    }
}