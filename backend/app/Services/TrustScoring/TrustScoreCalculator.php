<?php

namespace App\Services\TrustScoring;

use App\Models\User;

class TrustScoreCalculator
{
    public function calculate(User $user): float
    {
        $baseScore = 0.3;

        $positiveFactors = [
            'kyc_verified' => $user->kyc_status === 'verified' ? 0.2 : 0,
            'phone_verified' => $user->phone_verified ? 0.1 : 0,
            'successful_transactions' => $this->transactionScore($user),
            'account_age' => min($user->account_age_days / 365, 0.15),
            // Poids largement augmenté (0.05 -> 0.4) : un profil entièrement
            // rempli (bio, site, localisation, avatar, couverture) ET des
            // politiques vendeur configurées doit à lui seul amener un
            // compte tout neuf mais soigné à ~80% de confiance, sans
            // attendre un historique de transactions.
            'completed_profile' => $this->profileCompleteness($user),
        ];

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
        $fields = ['full_name', 'email', 'username', 'avatar_url', 'cover_url', 'city', 'region', 'bio', 'website'];
        $filled = collect($fields)->filter(fn($f) => !empty($user->$f))->count();
        $fieldsScore = ($filled / count($fields)) * 0.3;

        $policiesScore = !empty($user->seller_policies) ? 0.1 : 0;

        return $fieldsScore + $policiesScore;
    }

    public function recalculateAll(): int
    {
        $count = 0;
        User::chunk(100, function ($users) use (&$count) {
            foreach ($users as $user) {
                $newScore = $this->calculate($user);
                $user->forceFill(['trust_score' => $newScore])->save();
                $count++;
            }
        });
        return $count;
    }
}
