<?php

namespace App\Services\Admin;

use App\Models\FraudDetection;
use App\Models\ProductReport;
use App\Models\Transaction;
use App\Models\User;
use Illuminate\Support\Facades\DB;

/**
 * Crée de VRAIES alertes dans fraud_detections (jusqu'ici la table restait
 * toujours vide). Lancé par le scheduler toutes les heures et à la demande
 * depuis l'admin. Détecte :
 *  - paiements échoués répétés (suspicious_payment)
 *  - plusieurs comptes sur la même empreinte d'appareil (multiple_accounts)
 *  - annonces d'un vendeur signalées par plusieurs comptes distincts (fake_product)
 * Une alerte « pending_review » existante pour la même cible n'est jamais dupliquée.
 */
class FraudScanService
{
    /** @return array{suspicious_payment:int, multiple_accounts:int, fake_product:int} */
    public function run(): array
    {
        return [
            'suspicious_payment' => $this->failedPayments(),
            'multiple_accounts'  => $this->sharedDevices(),
            'fake_product'       => $this->reportedSellers(),
        ];
    }

    private function failedPayments(): int
    {
        $created = 0;

        $rows = Transaction::query()
            ->where('payment_status', 'failed')
            ->where('created_at', '>=', now()->subDays(7))
            ->select('buyer_id', DB::raw('COUNT(*) as failures'))
            ->groupBy('buyer_id')
            ->havingRaw('COUNT(*) >= 3')
            ->get();

        foreach ($rows as $row) {
            if ($this->pendingExists($row->buyer_id, 'suspicious_payment')) {
                continue;
            }

            FraudDetection::create([
                'user_id'          => $row->buyer_id,
                'detection_type'   => 'suspicious_payment',
                'confidence_score' => min(0.95, 0.4 + 0.1 * (int) $row->failures),
                'evidence'         => ['failed_payments_7d' => (int) $row->failures],
            ]);
            $created++;
        }

        return $created;
    }

    private function sharedDevices(): int
    {
        $created = 0;

        $groups = User::query()
            ->whereNotNull('device_fingerprint')
            ->where('device_fingerprint', '!=', '')
            ->where('role', 'user')
            ->whereNull('anonymized_at')
            ->select('device_fingerprint', DB::raw('COUNT(*) as accounts'))
            ->groupBy('device_fingerprint')
            ->havingRaw('COUNT(*) >= 3')
            ->limit(200)
            ->get();

        foreach ($groups as $group) {
            $hash = sha1((string) $group->device_fingerprint);

            $exists = FraudDetection::query()
                ->where('detection_type', 'multiple_accounts')
                ->where('status', 'pending_review')
                ->where('evidence->fingerprint_hash', $hash)
                ->exists();
            if ($exists) {
                continue;
            }

            $users = User::where('device_fingerprint', $group->device_fingerprint)
                ->orderBy('created_at')
                ->limit(10)
                ->pluck('id')
                ->all();

            FraudDetection::create([
                'user_id'          => $users[0] ?? null,
                'detection_type'   => 'multiple_accounts',
                'confidence_score' => min(0.9, 0.35 + 0.1 * (int) $group->accounts),
                'evidence'         => [
                    'fingerprint_hash' => $hash,
                    'accounts'         => (int) $group->accounts,
                    'user_ids'         => $users,
                ],
            ]);
            $created++;
        }

        return $created;
    }

    private function reportedSellers(): int
    {
        $created = 0;

        $rows = ProductReport::query()
            ->join('products', 'products.id', '=', 'product_reports.product_id')
            ->where('product_reports.status', 'pending')
            ->where('product_reports.created_at', '>=', now()->subDays(30))
            ->select('products.user_id', DB::raw('COUNT(DISTINCT product_reports.reporter_id) as reporters'))
            ->groupBy('products.user_id')
            ->havingRaw('COUNT(DISTINCT product_reports.reporter_id) >= 3')
            ->get();

        foreach ($rows as $row) {
            if ($this->pendingExists($row->user_id, 'fake_product')) {
                continue;
            }

            FraudDetection::create([
                'user_id'          => $row->user_id,
                'detection_type'   => 'fake_product',
                'confidence_score' => min(0.9, 0.3 + 0.1 * (int) $row->reporters),
                'evidence'         => ['distinct_reporters_30d' => (int) $row->reporters],
            ]);
            $created++;
        }

        return $created;
    }

    private function pendingExists(?string $userId, string $type): bool
    {
        return FraudDetection::query()
            ->where('user_id', $userId)
            ->where('detection_type', $type)
            ->where('status', 'pending_review')
            ->exists();
    }
}
