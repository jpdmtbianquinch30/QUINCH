<?php

namespace App\Services\Admin;

use App\Models\Product;
use App\Models\ProductReport;
use App\Models\SiteSetting;
use App\Models\User;

/**
 * Masquage automatique : quand assez de comptes DISTINCTS signalent une annonce
 * (pondérés par leur fiabilité), elle passe en « à vérifier » (masquée, flag
 * hidden_by_system) jusqu'à décision d'un modérateur.
 */
class ReportAutomationService
{
    public function __construct(private ModerationService $moderation) {}

    public function onProductReported(ProductReport $report): void
    {
        $product = Product::find($report->product_id);
        if (!$product || $product->status !== 'active') {
            return;
        }

        $minReporters = max(2, (int) SiteSetting::get('moderation.auto_hide_reporters', 3));
        $minWeight = (float) SiteSetting::get('moderation.auto_hide_weight', 1.5);

        $reports = ProductReport::where('product_id', $product->id)
            ->where('status', 'pending')
            ->with('reporter:id,trust_score,created_at,false_reports_count')
            ->get()
            ->unique('reporter_id');

        if ($reports->count() < $minReporters) {
            return;
        }

        $weight = $reports->sum(fn (ProductReport $r) => $this->reporterWeight($r->reporter));

        if ($weight >= $minWeight) {
            $this->moderation->hideProduct(
                $product,
                null,
                "Masquée automatiquement : {$reports->count()} signalements de comptes distincts",
                true,
                true
            );
        }
    }

    /** Poids d'un signaleur : sa confiance, réduite s'il est tout récent ou abuse des faux signalements. */
    public function reporterWeight(?User $reporter): float
    {
        if (!$reporter) {
            return 0.0;
        }

        $weight = (float) ($reporter->trust_score ?? 0.5);

        if ($reporter->created_at && $reporter->created_at->gt(now()->subDays(3))) {
            $weight *= 0.3;
        }

        if ((int) $reporter->false_reports_count >= 3) {
            $weight *= 0.2;
        }

        return round($weight, 3);
    }
}
