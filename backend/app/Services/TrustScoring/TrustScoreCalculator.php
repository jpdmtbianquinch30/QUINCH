<?php

namespace App\Services\TrustScoring;

use App\Models\User;

class TrustScoreCalculator
{
    public function calculate(User $user): float
    {
        $baseScore = 0.5;

        // Positive factors
        $positiveFactors = [
            'kyc_verified' => $user->kyc_status === 'verified' ? 0.2 : 0,
            'phone_verified' => $user->phone_verified ? 0.1 : 0,
            'successful_transactions' => $this->transactionScore($user),
            'account_age' => min($user->account_age_days / 365, 0.15),
            'completed_profile' => $this->profileCompleteness($user),
        ];

        // Negative factors
        $negativeFactors = [
            'failed_transactions' => -0.05 * $user->purchasedTransactions()
                ->where('payment_status', 'failed')
                ->count(),
            'suspicious_activities' => $user->last_suspicious_activity ? -0.15 : 0,
        ];

        $score = $baseScore + array_sum($positiveFactors) + array_sum($negativeFactors);

        return max(0, min(1, round($score, 2)));
    }

    private function transactionScore(User $user): float
    {
        $completed = $user->soldTransactions()->completed()->count()
                   + $user->purchasedTransactions()->completed()->count();

        return min($completed * 0.02, 0.2);
    }

    private function profileCompleteness(User $user): float
    {
        $fields = ['full_name', 'email', 'username', 'avatar_url', 'city', 'region'];
        $filled = collect($fields)->filter(fn($f) => !empty($user->$f))->count();

        return ($filled / count($fields)) * 0.05;
    }

    public function recalculateAll(): int
    {
        $count = 0;
        User::chunk(100, function ($users) use (&$count) {
            foreach ($users as $user) {
                $newScore = $this->calculate($user);
                $user->update(['trust_score' => $newScore]);
                $count++;
            }
        });
        return $count;
    }
}
