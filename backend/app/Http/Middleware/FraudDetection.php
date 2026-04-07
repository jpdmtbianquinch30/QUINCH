<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Symfony\Component\HttpFoundation\Response;

class FraudDetection
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if ($user) {
            $suspiciousPatterns = [];

            // Check if user has too many failed payments
            if ($user->purchasedTransactions()->where('payment_failure_count', '>=', 3)->exists()) {
                $suspiciousPatterns[] = 'excessive_payment_failures';
            }

            // Check rapid transaction frequency
            $recentTransactions = $user->purchasedTransactions()
                ->where('created_at', '>=', now()->subMinutes(5))
                ->count();

            if ($recentTransactions > 5) {
                $suspiciousPatterns[] = 'rapid_transactions';
            }

            if (!empty($suspiciousPatterns)) {
                Log::channel('daily')->warning('Suspicious activity detected', [
                    'ip' => $request->ip(),
                    'user_id' => $user->id,
                    'patterns' => $suspiciousPatterns,
                ]);

                $user->update(['last_suspicious_activity' => now()]);
            }
        }

        return $next($request);
    }
}
