<?php

namespace App\Services\Admin;

use App\Models\BlockedVideoHash;
use App\Models\Product;
use App\Models\ProductVideo;
use App\Models\User;
use App\Services\NotificationService;
use Illuminate\Support\Facades\DB;

/**
 * Cœur de la post-modération : un rejet fait TOUT d'un coup
 * (vidéo retirée du feed et du streaming, produit conservé ou masqué,
 * vendeur notifié avec le motif, empreinte blacklistée, strike, journal).
 */
class ModerationService
{
    public function __construct(
        private NotificationService $notif,
        private StrikeService $strikes
    ) {}

    /**
     * @param string $status 'rejected' (retrait définitif) ou 'flagged' (mise en vérification)
     * @param string $action 'video_only' (le produit reste en ligne sans vidéo) ou 'hide_product'
     */
    public function rejectVideo(
        ProductVideo $video,
        ?User $by,
        string $reason,
        string $status = 'rejected',
        string $action = 'video_only',
        bool $strike = true
    ): void {
        $product = $video->product()->first();

        DB::transaction(function () use ($video, $by, $reason, $status, $action, $product) {
            $video->forceFill([
                'moderation_status'       => $status,
                'moderation_reason'       => mb_substr($reason, 0, 500),
                'moderated_by'            => $by?->id,
                'moderated_at'            => now(),
                'removed_from_product_id' => $product?->id ?? $video->removed_from_product_id,
            ])->save();

            if ($status === 'rejected' && $video->hash_sha256) {
                BlockedVideoHash::firstOrCreate(
                    ['hash_sha256' => $video->hash_sha256],
                    ['reason' => mb_substr($reason, 0, 500), 'created_by' => $by?->id]
                );
            }

            if ($product && $status === 'rejected') {
                // Le produit reste en ligne mais sans la vidéo retirée.
                $product->forceFill(['video_id' => null])->save();
            }
        });

        if ($product && $action === 'hide_product') {
            $this->hideProduct($product, $by, $reason, false, false);
        }

        AdminLogger::log($by, $status === 'rejected' ? 'video_rejected' : 'video_flagged', 'ProductVideo', $video->id, [
            'reason'     => $reason,
            'action'     => $action,
            'product_id' => $product?->id,
            'seller_id'  => $video->user_id,
        ], 'warning');

        if ($strike && $status === 'rejected' && $video->user) {
            $this->strikes->add($video->user, "Vidéo retirée : {$reason}", $by, $product?->id, $video->id);
        }

        $this->notifySeller(
            $video->user_id,
            $status === 'rejected' ? 'Votre vidéo a été retirée' : 'Votre vidéo est en cours de vérification',
            ($status === 'rejected'
                ? "Motif : {$reason}. Si vous pensez qu'il s'agit d'une erreur, vous pouvez contester cette décision."
                : "Elle n'est plus visible le temps de la vérification. Motif : {$reason}"),
            null,
            [
                'kind' => $status === 'rejected' ? 'video_removed' : 'video_review',
                'concerned_admin_id' => $by?->id,
                'contest' => ['target_type' => 'video', 'target_id' => $video->id],
            ]
        );
    }

    /** Approuve une vidéo, ou la rétablit si elle avait été rejetée / mise en vérification. */
    public function approveVideo(ProductVideo $video, ?User $by, ?string $note = null): void
    {
        $wasRemoved = in_array($video->moderation_status, ['rejected', 'flagged'], true);
        $productId = $video->removed_from_product_id;

        DB::transaction(function () use ($video, $by, $wasRemoved, $productId) {
            $video->forceFill([
                'moderation_status'       => 'approved',
                'moderation_reason'       => null,
                'moderated_by'            => $by?->id,
                'moderated_at'            => now(),
                'removed_from_product_id' => null,
            ])->save();

            if ($wasRemoved) {
                if ($video->hash_sha256) {
                    BlockedVideoHash::where('hash_sha256', $video->hash_sha256)->delete();
                }

                if ($productId) {
                    $product = Product::find($productId);
                    if ($product && $product->video_id === null) {
                        $product->forceFill(['video_id' => $video->id])->save();
                    }
                }

                $this->strikes->revokeForVideo($video->id);
            }
        });

        AdminLogger::log($by, 'video_approved', 'ProductVideo', $video->id, [
            'restored' => $wasRemoved, 'note' => $note,
        ]);

        if ($wasRemoved) {
            $this->notifySeller($video->user_id, 'Votre vidéo a été rétablie', 'Après réexamen, votre vidéo est de nouveau visible.', null, ['kind' => 'video_restored']);
        }
    }

    public function hideProduct(Product $product, ?User $by, string $reason, bool $system = false, bool $notify = true): void
    {
        $product->forceFill([
            'status'            => 'disabled',
            'moderation_reason' => mb_substr($reason, 0, 500),
            'moderated_by'      => $by?->id,
            'moderated_at'      => now(),
            'hidden_by_system'  => $system,
        ])->save();

        AdminLogger::log($by, $system ? 'product_auto_hidden' : 'product_hidden', 'Product', $product->id, [
            'reason' => $reason, 'title' => $product->title, 'seller_id' => $product->user_id,
        ], 'warning');

        if ($notify) {
            $this->notifySeller(
                $product->user_id,
                'Votre annonce a été masquée',
                "« " . mb_substr((string) $product->title, 0, 50) . " » n'est plus visible. Motif : {$reason}",
                null,
                ['kind' => 'product_hidden', 'concerned_admin_id' => $by?->id, 'contest' => ['target_type' => 'product', 'target_id' => $product->id]]
            );
        }
    }

    public function restoreProduct(Product $product, ?User $by, ?string $note = null): void
    {
        $product->forceFill([
            'status'            => 'active',
            'moderation_reason' => null,
            'moderated_by'      => $by?->id,
            'moderated_at'      => now(),
            'hidden_by_system'  => false,
        ])->save();

        AdminLogger::log($by, 'product_restored', 'Product', $product->id, ['note' => $note, 'title' => $product->title]);

        $this->notifySeller(
            $product->user_id,
            'Votre annonce est de nouveau en ligne',
            "« " . mb_substr((string) $product->title, 0, 50) . " » a été réactivée par la modération.",
            null,
            ['kind' => 'product_restored']
        );
    }

    /** Suppression douce : la ligne reste en base (preuves, litiges). */
    public function deleteProduct(Product $product, ?User $by, string $reason): void
    {
        $product->forceFill([
            'moderation_reason' => mb_substr($reason, 0, 500),
            'moderated_by'      => $by?->id,
            'moderated_at'      => now(),
        ])->save();
        $product->delete();

        AdminLogger::log($by, 'product_deleted', 'Product', $product->id, [
            'reason' => $reason, 'title' => $product->title, 'seller_id' => $product->user_id,
        ], 'critical');

        $this->notifySeller(
            $product->user_id,
            'Votre annonce a été supprimée',
            "« " . mb_substr((string) $product->title, 0, 50) . " » a été supprimée par la modération. Motif : {$reason}",
            null,
            ['kind' => 'product_deleted', 'concerned_admin_id' => $by?->id, 'contest' => ['target_type' => 'product', 'target_id' => $product->id]]
        );
    }

    public function notifySeller(string $userId, string $title, string $body, ?string $url = null, array $meta = []): void
    {
        try {
            $this->notif->notifyAdmin($userId, $title, $body, $url, $meta);
        } catch (\Throwable $e) {
            logger()->warning('Notification de modération échouée: ' . $e->getMessage());
        }
    }
}
