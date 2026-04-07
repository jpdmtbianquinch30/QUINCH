<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\AdminActionLog;
use App\Models\FraudDetection;
use App\Models\Product;
use App\Models\ProductReport;
use App\Models\ProductVideo;
use App\Models\Transaction;
use App\Models\User;
use App\Models\UserBadge;
use App\Models\UserFollow;
use App\Models\UserReview;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AdminController extends Controller
{
    public function metrics(): JsonResponse
    {
        $todayStart = now()->startOfDay();
        $weekStart = now()->startOfWeek();
        $monthStart = now()->startOfMonth();

        return response()->json([
            'users' => [
                'total' => User::count(),
                'active' => User::active()->count(),
                'clients' => User::clients()->count(),
                'admins' => User::admins()->count(),
                'verified' => User::verified()->count(),
                'new_today' => User::where('created_at', '>=', $todayStart)->count(),
                'new_this_week' => User::where('created_at', '>=', $weekStart)->count(),
                'new_this_month' => User::where('created_at', '>=', $monthStart)->count(),
                'suspended' => User::where('account_status', 'suspended')->count(),
            ],
            'products' => [
                'total' => Product::count(),
                'active' => Product::active()->count(),
                'sold' => Product::where('status', 'sold')->count(),
                'new_today' => Product::where('created_at', '>=', $todayStart)->count(),
            ],
            'transactions' => [
                'total' => Transaction::count(),
                'completed' => Transaction::completed()->count(),
                'pending' => Transaction::pending()->count(),
                'disputed' => Transaction::where('security_check', 'manual_review')->count(),
                'revenue' => Transaction::completed()->sum('amount'),
                'total_fees' => Transaction::completed()->sum('transaction_fee'),
                'today_volume' => Transaction::completed()->where('created_at', '>=', $todayStart)->sum('amount'),
                'today_count' => Transaction::where('created_at', '>=', $todayStart)->count(),
                'week_volume' => Transaction::completed()->where('created_at', '>=', $weekStart)->sum('amount'),
                'month_volume' => Transaction::completed()->where('created_at', '>=', $monthStart)->sum('amount'),
                'avg_basket' => Transaction::completed()->avg('amount') ?? 0,
                'success_rate' => Transaction::count() > 0
                    ? round(Transaction::completed()->count() / Transaction::count() * 100, 1)
                    : 0,
            ],
            'moderation' => [
                'pending_videos' => ProductVideo::pending()->count(),
                'flagged_videos' => ProductVideo::where('moderation_status', 'flagged')->count(),
                'reports' => ProductReport::where('status', 'pending')->count(),
            ],
            'security' => [
                'fraud_alerts' => FraudDetection::pendingReview()->count(),
                'suspicious_users' => User::whereNotNull('last_suspicious_activity')
                    ->where('last_suspicious_activity', '>=', now()->subDays(7))
                    ->count(),
            ],
            'social' => [
                'total_reviews' => UserReview::count(),
                'total_badges' => UserBadge::count(),
                'total_follows' => UserFollow::count(),
            ],
        ]);
    }

    public function realTime(): JsonResponse
    {
        return response()->json([
            'active_users' => User::where('updated_at', '>=', now()->subMinutes(5))->count(),
            'transactions_per_minute' => Transaction::where('created_at', '>=', now()->subMinute())->count(),
            'transactions_today' => Transaction::whereDate('created_at', today())->count(),
            'revenue_today' => Transaction::completed()->whereDate('created_at', today())->sum('amount'),
            'pending_moderations' => ProductVideo::pending()->count(),
            'fraud_alerts' => FraudDetection::pendingReview()->count(),
            'pending_reports' => ProductReport::where('status', 'pending')->count(),
            'system_health' => 100,
            'timestamp' => now(),
        ]);
    }

    public function transactionReport(Request $request): JsonResponse
    {
        $days = $request->get('days', 30);

        $transactions = Transaction::selectRaw('
                DATE(created_at) as date,
                COUNT(*) as total,
                SUM(CASE WHEN payment_status = "completed" THEN 1 ELSE 0 END) as completed,
                SUM(CASE WHEN payment_status = "failed" THEN 1 ELSE 0 END) as failed,
                SUM(CASE WHEN payment_status = "completed" THEN amount ELSE 0 END) as volume,
                payment_method
            ')
            ->where('created_at', '>=', now()->subDays($days))
            ->groupByRaw('DATE(created_at), payment_method')
            ->orderBy('date')
            ->get();

        $summary = [
            'total_transactions' => Transaction::where('created_at', '>=', now()->subDays($days))->count(),
            'total_volume' => Transaction::completed()->where('created_at', '>=', now()->subDays($days))->sum('amount'),
            'total_fees' => Transaction::completed()->where('created_at', '>=', now()->subDays($days))->sum('transaction_fee'),
            'success_rate' => Transaction::where('created_at', '>=', now()->subDays($days))->count() > 0
                ? round(Transaction::completed()->where('created_at', '>=', now()->subDays($days))->count()
                    / Transaction::where('created_at', '>=', now()->subDays($days))->count() * 100, 1)
                : 0,
        ];

        return response()->json(['report' => $transactions, 'summary' => $summary]);
    }

    public function fraudReport(): JsonResponse
    {
        $fraudCases = FraudDetection::with(['user:id,full_name,phone_number,trust_score'])
            ->latest()
            ->paginate(20);

        return response()->json($fraudCases);
    }

    public function userReport(Request $request): JsonResponse
    {
        $days = $request->get('days', 30);
        $since = now()->subDays($days);

        $newUsers = User::selectRaw('DATE(created_at) as date, COUNT(*) as count')
            ->where('created_at', '>=', $since)
            ->groupByRaw('DATE(created_at)')
            ->orderBy('date')
            ->get();

        $topSellers = User::withCount(['soldTransactions as sales_count' => function ($q) use ($since) {
                $q->where('created_at', '>=', $since);
            }])
            ->withSum(['soldTransactions as revenue' => function ($q) use ($since) {
                $q->where('created_at', '>=', $since)->where('payment_status', 'completed');
            }], 'amount')
            ->orderByDesc('revenue')
            ->limit(10)
            ->get(['id', 'full_name', 'username', 'avatar_url', 'trust_score']);

        return response()->json([
            'growth' => $newUsers,
            'top_sellers' => $topSellers,
            'total_users' => User::count(),
            'new_in_period' => User::where('created_at', '>=', $since)->count(),
        ]);
    }

    public function overviewReport(Request $request): JsonResponse
    {
        $days = $request->get('days', 7);
        $since = now()->subDays($days);

        $daily = [];
        for ($i = $days; $i >= 0; $i--) {
            $date = now()->subDays($i)->format('Y-m-d');
            $dayStart = now()->subDays($i)->startOfDay();
            $dayEnd = now()->subDays($i)->endOfDay();

            $daily[] = [
                'date' => $date,
                'users' => User::whereBetween('created_at', [$dayStart, $dayEnd])->count(),
                'transactions' => Transaction::whereBetween('created_at', [$dayStart, $dayEnd])->count(),
                'revenue' => Transaction::completed()->whereBetween('created_at', [$dayStart, $dayEnd])->sum('amount'),
                'products' => Product::whereBetween('created_at', [$dayStart, $dayEnd])->count(),
            ];
        }

        return response()->json(['daily' => $daily, 'period' => $days]);
    }
    public function deleteAllVideos(): JsonResponse
    {
        // Delete products that have videos first to avoid FK constraints or orphans
        Product::whereNotNull('video_id')->delete();
        
        // Then delete the videos
        ProductVideo::query()->delete();
        
        return response()->json(['message' => 'All videos and associated products deleted successfully']);
    }

    public function resetData(): JsonResponse
    {
        // 1. Delete all Transactions
        Transaction::query()->delete();

        // 2. Delete all Products (cascades to likes, saves, etc.)
        Product::query()->delete();
        
        // 3. Delete all Videos (now safe as products are gone)
        ProductVideo::query()->delete();

        // 4. Delete all Conversations/Messages (optional but good for clean slate)
        \App\Models\Conversation::query()->delete();

        // 5. Delete all Notifications
        \App\Models\Notification::query()->delete();
        
        // 6. Delete all users except admins
        User::whereNotIn('role', ['admin', 'super_admin'])->delete();

        return response()->json(['message' => 'System reset successfully: Users, Videos, Products, and Transactions deleted.']);
    }
}
