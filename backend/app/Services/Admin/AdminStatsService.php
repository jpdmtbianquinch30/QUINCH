<?php

namespace App\Services\Admin;

use App\Models\PremiumSubscription;
use App\Models\Product;
use App\Models\User;
use App\Models\UserBadge;
use App\Models\UserFollow;
use App\Models\UserReview;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Statistiques du tableau de bord. Avant : ~35 COUNT par appel sans cache,
 * et une boucle de 5 requêtes PAR JOUR dans overviewReport (?days=100000 =>
 * des centaines de milliers de requêtes). Maintenant : requêtes agrégées
 * (FILTER), GROUP BY date, jours bornés, cache court.
 */
class AdminStatsService
{
    public const MAX_DAYS = 90;

    public static function clampDays(mixed $days, int $default = 7): int
    {
        $days = is_numeric($days) ? (int) $days : $default;

        return max(1, min(self::MAX_DAYS, $days));
    }

    public function metrics(): array
    {
        return Cache::remember('admin.metrics', 60, fn () => $this->computeMetrics());
    }

    private function computeMetrics(): array
    {
        $today = now()->startOfDay();
        $week = now()->startOfWeek();
        $month = now()->startOfMonth();

        $u = DB::table('users')->selectRaw("
            COUNT(*) FILTER (WHERE anonymized_at IS NULL) AS total,
            COUNT(*) FILTER (WHERE account_status = 'active') AS active,
            COUNT(*) FILTER (WHERE role = 'user' AND anonymized_at IS NULL) AS clients,
            COUNT(*) FILTER (WHERE role IN ('moderator','admin','super_admin')) AS staff,
            COUNT(*) FILTER (WHERE kyc_status = 'verified') AS verified,
            COUNT(*) FILTER (WHERE created_at >= ?) AS new_today,
            COUNT(*) FILTER (WHERE created_at >= ?) AS new_this_week,
            COUNT(*) FILTER (WHERE created_at >= ?) AS new_this_month,
            COUNT(*) FILTER (WHERE account_status = 'suspended') AS suspended,
            COUNT(*) FILTER (WHERE account_status = 'banned') AS banned,
            COUNT(*) FILTER (WHERE is_premium = true AND premium_expires_at > NOW()) AS premium,
            COUNT(*) FILTER (WHERE last_suspicious_activity >= ?) AS suspicious
        ", [$today, $week, $month, now()->subDays(7)])->first();

        $p = DB::table('products')->whereNull('deleted_at')->selectRaw("
            COUNT(*) AS total,
            COUNT(*) FILTER (WHERE status = 'active') AS active,
            COUNT(*) FILTER (WHERE status = 'sold') AS sold,
            COUNT(*) FILTER (WHERE status = 'disabled') AS hidden,
            COUNT(*) FILTER (WHERE created_at >= ?) AS new_today
        ", [$today])->first();

        $t = DB::table('transactions')->selectRaw("
            COUNT(*) AS total,
            COUNT(*) FILTER (WHERE payment_status = 'completed') AS completed,
            COUNT(*) FILTER (WHERE payment_status = 'pending') AS pending,
            COUNT(*) FILTER (WHERE order_status = 'disputed') AS disputed,
            COALESCE(SUM(amount) FILTER (WHERE payment_status = 'completed'), 0) AS revenue,
            COALESCE(SUM(transaction_fee) FILTER (WHERE payment_status = 'completed'), 0) AS total_fees,
            COALESCE(SUM(amount) FILTER (WHERE payment_status = 'completed' AND created_at >= ?), 0) AS today_volume,
            COUNT(*) FILTER (WHERE created_at >= ?) AS today_count,
            COALESCE(SUM(amount) FILTER (WHERE payment_status = 'completed' AND created_at >= ?), 0) AS week_volume,
            COALESCE(SUM(amount) FILTER (WHERE payment_status = 'completed' AND created_at >= ?), 0) AS month_volume,
            COALESCE(AVG(amount) FILTER (WHERE payment_status = 'completed'), 0) AS avg_basket
        ", [$today, $today, $week, $month])->first();

        $videos = DB::table('product_videos')->selectRaw("
            COUNT(*) FILTER (WHERE moderation_status = 'pending') AS pending,
            COUNT(*) FILTER (WHERE moderation_status = 'flagged') AS flagged
        ")->first();

        $reports = (int) DB::table('product_reports')->where('status', 'pending')->count();
        $userReports = (int) DB::table('user_reports')->where('status', 'pending')->count();
        $tickets = (int) DB::table('support_tickets')->where('status', 'pending')->count();
        $appeals = Schema::hasTable('moderation_appeals')
            ? (int) DB::table('moderation_appeals')->where('status', 'pending')->count()
            : 0;
        $fraud = (int) DB::table('fraud_detections')->where('status', 'pending_review')->count();

        $totalTx = (int) $t->total;

        return [
            'users' => [
                'total' => (int) $u->total,
                'active' => (int) $u->active,
                'clients' => (int) $u->clients,
                'admins' => (int) $u->staff,
                'verified' => (int) $u->verified,
                'new_today' => (int) $u->new_today,
                'new_this_week' => (int) $u->new_this_week,
                'new_this_month' => (int) $u->new_this_month,
                'suspended' => (int) $u->suspended,
                'banned' => (int) $u->banned,
                'premium' => (int) $u->premium,
            ],
            'products' => [
                'total' => (int) $p->total,
                'active' => (int) $p->active,
                'sold' => (int) $p->sold,
                'hidden' => (int) $p->hidden,
                'new_today' => (int) $p->new_today,
            ],
            'transactions' => [
                'total' => $totalTx,
                'completed' => (int) $t->completed,
                'pending' => (int) $t->pending,
                'disputed' => (int) $t->disputed,
                'revenue' => (float) $t->revenue,
                'total_fees' => (float) $t->total_fees,
                'today_volume' => (float) $t->today_volume,
                'today_count' => (int) $t->today_count,
                'week_volume' => (float) $t->week_volume,
                'month_volume' => (float) $t->month_volume,
                'avg_basket' => (float) $t->avg_basket,
                'success_rate' => $totalTx > 0 ? round(((int) $t->completed) / $totalTx * 100, 1) : 0,
            ],
            'moderation' => [
                'pending_videos' => (int) $videos->pending,
                'flagged_videos' => (int) $videos->flagged,
                'reports' => $reports,
                'user_reports' => $userReports,
                'tickets' => $tickets,
                'appeals' => $appeals,
            ],
            'security' => [
                'fraud_alerts' => $fraud,
                'suspicious_users' => (int) $u->suspicious,
            ],
            'social' => [
                'total_reviews' => UserReview::count(),
                'total_badges' => UserBadge::count(),
                'total_follows' => UserFollow::count(),
            ],
        ];
    }

    public function realTime(): array
    {
        $health = $this->health();

        return [
            // last_seen_at (alimenté par TouchLastSeen) et non updated_at.
            'active_users' => User::where('last_seen_at', '>=', now()->subMinutes(5))->count(),
            'transactions_per_minute' => DB::table('transactions')->where('created_at', '>=', now()->subMinute())->count(),
            'transactions_today' => DB::table('transactions')->where('created_at', '>=', now()->startOfDay())->count(),
            'revenue_today' => (float) DB::table('transactions')
                ->where('payment_status', 'completed')
                ->where('created_at', '>=', now()->startOfDay())
                ->sum('amount'),
            'pending_moderations' => DB::table('product_videos')->where('moderation_status', 'pending')->count(),
            'fraud_alerts' => DB::table('fraud_detections')->where('status', 'pending_review')->count(),
            'pending_reports' => DB::table('product_reports')->where('status', 'pending')->count(),
            'system_health' => $health['score'],
            'health_checks' => $health['checks'],
            'timestamp' => now(),
        ];
    }

    /** Santé réelle (base, cache, file d'attente, stockage) au lieu du « 100 » codé en dur. */
    public function health(): array
    {
        return Cache::remember('admin.health', 30, function () {
            $score = 100;
            $checks = [];

            try {
                DB::select('select 1');
                $checks['database'] = ['ok' => true, 'detail' => 'connectée'];
            } catch (\Throwable $e) {
                $checks['database'] = ['ok' => false, 'detail' => 'injoignable'];
                $score -= 50;
            }

            try {
                Cache::put('admin.health.ping', 1, 10);
                $ok = (int) Cache::get('admin.health.ping') === 1;
                $checks['cache'] = ['ok' => $ok, 'detail' => $ok ? 'ok' : 'lecture impossible'];
                if (!$ok) {
                    $score -= 20;
                }
            } catch (\Throwable $e) {
                $checks['cache'] = ['ok' => false, 'detail' => 'indisponible'];
                $score -= 20;
            }

            try {
                if (config('queue.default') === 'database' && Schema::hasTable('jobs')) {
                    $backlog = (int) DB::table('jobs')->count();
                    $checks['queue'] = ['ok' => $backlog < 1000, 'detail' => "{$backlog} job(s) en attente"];
                    if ($backlog >= 1000) {
                        $score -= 15;
                    }
                } else {
                    $checks['queue'] = ['ok' => true, 'detail' => 'driver ' . config('queue.default')];
                }

                if (Schema::hasTable('failed_jobs')) {
                    $failed = (int) DB::table('failed_jobs')->where('failed_at', '>=', now()->subDay())->count();
                    $checks['failed_jobs_24h'] = ['ok' => $failed === 0, 'detail' => "{$failed} échec(s)"];
                    if ($failed > 0) {
                        $score -= min(15, $failed);
                    }
                }
            } catch (\Throwable $e) {
                $checks['queue'] = ['ok' => false, 'detail' => 'illisible'];
                $score -= 10;
            }

            try {
                $path = storage_path('app');
                $free = @disk_free_space($path);
                $total = @disk_total_space($path);
                if ($free !== false && $total) {
                    $pct = round($free / $total * 100);
                    $checks['storage'] = ['ok' => $pct >= 10, 'detail' => "{$pct}% libre"];
                    if ($pct < 10) {
                        $score -= 10;
                    }
                }
            } catch (\Throwable $e) {
                // Non bloquant.
            }

            return ['score' => max(0, $score), 'checks' => $checks];
        });
    }

    /** Série journalière : 4 requêtes GROUP BY quel que soit le nombre de jours. */
    public function overview(int $days): array
    {
        $days = self::clampDays($days);
        $from = now()->subDays($days)->startOfDay();

        $users = DB::table('users')->where('created_at', '>=', $from)
            ->selectRaw('DATE(created_at) AS d, COUNT(*) AS c')->groupByRaw('DATE(created_at)')->pluck('c', 'd');

        $tx = DB::table('transactions')->where('created_at', '>=', $from)
            ->selectRaw('DATE(created_at) AS d, COUNT(*) AS c')->groupByRaw('DATE(created_at)')->pluck('c', 'd');

        $revenue = DB::table('transactions')->where('created_at', '>=', $from)->where('payment_status', 'completed')
            ->selectRaw('DATE(created_at) AS d, SUM(amount) AS s')->groupByRaw('DATE(created_at)')->pluck('s', 'd');

        $products = DB::table('products')->whereNull('deleted_at')->where('created_at', '>=', $from)
            ->selectRaw('DATE(created_at) AS d, COUNT(*) AS c')->groupByRaw('DATE(created_at)')->pluck('c', 'd');

        $daily = [];
        for ($i = $days; $i >= 0; $i--) {
            $date = now()->subDays($i)->format('Y-m-d');
            $daily[] = [
                'date' => $date,
                'users' => (int) ($users[$date] ?? 0),
                'transactions' => (int) ($tx[$date] ?? 0),
                'revenue' => (float) ($revenue[$date] ?? 0),
                'products' => (int) ($products[$date] ?? 0),
            ];
        }

        return ['daily' => $daily, 'period' => $days];
    }

    public function transactionReport(int $days): array
    {
        $days = self::clampDays($days, 30);
        $from = now()->subDays($days);

        $report = DB::table('transactions')
            ->where('created_at', '>=', $from)
            ->selectRaw("
                DATE(created_at) AS date,
                COUNT(*) AS total,
                COUNT(*) FILTER (WHERE payment_status = 'completed') AS completed,
                COUNT(*) FILTER (WHERE payment_status = 'failed') AS failed,
                COALESCE(SUM(amount) FILTER (WHERE payment_status = 'completed'), 0) AS volume,
                payment_method
            ")
            ->groupByRaw('DATE(created_at), payment_method')
            ->orderBy('date')
            ->get();

        $s = DB::table('transactions')->where('created_at', '>=', $from)->selectRaw("
            COUNT(*) AS total,
            COUNT(*) FILTER (WHERE payment_status = 'completed') AS completed,
            COALESCE(SUM(amount) FILTER (WHERE payment_status = 'completed'), 0) AS volume,
            COALESCE(SUM(transaction_fee) FILTER (WHERE payment_status = 'completed'), 0) AS fees
        ")->first();

        return [
            'report' => $report,
            'summary' => [
                'total_transactions' => (int) $s->total,
                'total_volume' => (float) $s->volume,
                'total_fees' => (float) $s->fees,
                'success_rate' => (int) $s->total > 0 ? round(((int) $s->completed) / (int) $s->total * 100, 1) : 0,
            ],
        ];
    }

    public function userReport(int $days): array
    {
        $days = self::clampDays($days, 30);
        $since = now()->subDays($days);

        $growth = DB::table('users')->where('created_at', '>=', $since)
            ->selectRaw('DATE(created_at) AS date, COUNT(*) AS count')
            ->groupByRaw('DATE(created_at)')->orderBy('date')->get();

        // NULLS LAST : sous PostgreSQL, ORDER BY ... DESC place les NULL en
        // premier, donc les vendeurs SANS vente passaient devant les autres.
        $topSellers = User::query()
            ->select('users.id', 'users.full_name', 'users.username', 'users.avatar_url', 'users.trust_score')
            ->withCount(['soldTransactions as sales_count' => fn ($q) => $q->where('created_at', '>=', $since)])
            ->withSum(['soldTransactions as revenue' => fn ($q) => $q->where('created_at', '>=', $since)->where('payment_status', 'completed')], 'amount')
            ->orderByRaw('revenue DESC NULLS LAST')
            ->limit(10)
            ->get()
            ->filter(fn ($u) => (float) ($u->revenue ?? 0) > 0)
            ->values();

        return [
            'growth' => $growth,
            'top_sellers' => $topSellers,
            'total_users' => User::whereNull('anonymized_at')->count(),
            'new_in_period' => User::where('created_at', '>=', $since)->count(),
        ];
    }

    /** Finance : commissions + revenus Premium + frais de publication (absents jusqu'ici). */
    public function finance(int $days): array
    {
        $days = self::clampDays($days, 30);
        $from = now()->subDays($days)->startOfDay();

        $tx = DB::table('transactions')->where('created_at', '>=', $from)->selectRaw("
            COALESCE(SUM(amount) FILTER (WHERE payment_status = 'completed'), 0) AS gmv,
            COALESCE(SUM(transaction_fee) FILTER (WHERE payment_status = 'completed'), 0) AS commissions,
            COALESCE(SUM(amount) FILTER (WHERE payment_status = 'refunded'), 0) AS refunded,
            COUNT(*) FILTER (WHERE order_status = 'disputed') AS disputed
        ")->first();

        // Les abonnements offerts (admin_grant) ne sont pas du chiffre d'affaires.
        $premium = PremiumSubscription::query()
            ->whereIn('status', ['active', 'expired'])
            ->where('payment_method', '!=', 'admin_grant')
            ->where('starts_at', '>=', $from);

        $premiumTotal = (float) (clone $premium)->sum('amount');
        $premiumCount = (int) (clone $premium)->count();

        $listing = Product::withTrashed()
            ->where('listing_fee_status', 'paid')
            ->where('created_at', '>=', $from);
        $listingTotal = (float) (clone $listing)->sum('listing_fee_amount');
        $listingCount = (int) (clone $listing)->count();

        $byMethod = DB::table('transactions')->where('created_at', '>=', $from)->where('payment_status', 'completed')
            ->selectRaw('payment_method, COUNT(*) AS count, SUM(amount) AS volume, SUM(transaction_fee) AS fees')
            ->groupBy('payment_method')->get();

        $dailyFees = DB::table('transactions')->where('created_at', '>=', $from)->where('payment_status', 'completed')
            ->selectRaw('DATE(created_at) AS d, SUM(transaction_fee) AS s')->groupByRaw('DATE(created_at)')->pluck('s', 'd');
        $dailyPremium = DB::table('premium_subscriptions')->whereIn('status', ['active', 'expired'])
            ->where('payment_method', '!=', 'admin_grant')->where('starts_at', '>=', $from)
            ->selectRaw('DATE(starts_at) AS d, SUM(amount) AS s')->groupByRaw('DATE(starts_at)')->pluck('s', 'd');
        $dailyListing = DB::table('products')->where('listing_fee_status', 'paid')->where('created_at', '>=', $from)
            ->selectRaw('DATE(created_at) AS d, SUM(listing_fee_amount) AS s')->groupByRaw('DATE(created_at)')->pluck('s', 'd');

        $daily = [];
        for ($i = $days; $i >= 0; $i--) {
            $date = now()->subDays($i)->format('Y-m-d');
            $daily[] = [
                'date' => $date,
                'commissions' => (float) ($dailyFees[$date] ?? 0),
                'premium' => (float) ($dailyPremium[$date] ?? 0),
                'listing_fees' => (float) ($dailyListing[$date] ?? 0),
            ];
        }

        $commissions = (float) $tx->commissions;

        return [
            'period' => $days,
            'gmv' => (float) $tx->gmv,
            'commissions' => $commissions,
            'premium_revenue' => $premiumTotal,
            'premium_subscriptions' => $premiumCount,
            'listing_fees' => $listingTotal,
            'listing_fees_count' => $listingCount,
            'refunded' => (float) $tx->refunded,
            'disputed' => (int) $tx->disputed,
            'total_revenue' => $commissions + $premiumTotal + $listingTotal,
            'by_method' => $byMethod,
            'daily' => $daily,
        ];
    }
}
