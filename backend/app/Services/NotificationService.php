<?php

namespace App\Services;

use App\Models\NotificationPreference;
use App\Models\User;
use App\Models\UserNotification;

class NotificationService
{
    /**
     * Priority levels.
     * 'critical' => push + in_app (transactions, admin alerts)
     * 'normal'   => in_app (likes, follows, comments)
     * 'low'      => in_app only, groupable (mass likes)
     */
    const PRIORITY_CRITICAL = 'critical';
    const PRIORITY_NORMAL = 'normal';
    const PRIORITY_LOW = 'low';

    /**
     * Send a notification to a user, respecting preferences and grouping.
     */
    public function send(
        string $userId,
        string $type,
        string $title,
        string $body,
        array $options = []
    ): ?UserNotification {
        // Options
        $icon      = $options['icon'] ?? $this->defaultIcon($type);
        $actionUrl = $options['action_url'] ?? null;
        $data      = $options['data'] ?? null;
        $priority  = $options['priority'] ?? self::PRIORITY_NORMAL;
        $imageUrl  = $options['image_url'] ?? null;
        $senderId  = $options['sender_id'] ?? null;
        $groupKey  = $options['group_key'] ?? null;

        // Check user preferences
        if (!$this->isEnabled($userId, $type)) {
            return null;
        }

        // Grouping: if group_key is set, try to merge with existing unread notification
        if ($groupKey) {
            $existing = UserNotification::where('user_id', $userId)
                ->where('group_key', $groupKey)
                ->where('is_read', false)
                ->where('created_at', '>=', now()->subHours(24))
                ->first();

            if ($existing) {
                $existing->increment('group_count');
                $existing->update([
                    'title' => $title,
                    'body' => $body,
                    'image_url' => $imageUrl ?? $existing->image_url,
                    'updated_at' => now(),
                ]);
                return $existing;
            }
        }

        // Create the notification
        return UserNotification::create([
            'user_id'     => $userId,
            'type'        => $type,
            'title'       => $title,
            'body'        => $body,
            'icon'        => $icon,
            'action_url'  => $actionUrl,
            'data'        => $data,
            'priority'    => $priority,
            'image_url'   => $imageUrl,
            'sender_id'   => $senderId,
            'group_key'   => $groupKey,
            'group_count' => 1,
        ]);
    }

    /**
     * Check if a notification type is enabled for a user.
     */
    public function isEnabled(string $userId, string $type): bool
    {
        $pref = NotificationPreference::where('user_id', $userId)
            ->where('type', $type)
            ->first();

        if (!$pref) {
            // No preference saved => use defaults
            $defaults = NotificationPreference::defaultTypes();
            return $defaults[$type]['in_app'] ?? true;
        }

        return $pref->in_app_enabled;
    }

    /**
     * Check if push is enabled for a user + type.
     */
    public function isPushEnabled(string $userId, string $type): bool
    {
        $pref = NotificationPreference::where('user_id', $userId)
            ->where('type', $type)
            ->first();

        if (!$pref) {
            $defaults = NotificationPreference::defaultTypes();
            return $defaults[$type]['push'] ?? false;
        }

        return $pref->push_enabled;
    }

    // ─── Convenience methods for each event type ─────────────────────────

    /**
     * New private message.
     */
    public function notifyMessage(string $userId, User $sender, string $conversationId, string $preview): ?UserNotification
    {
        return $this->send($userId, 'message', 'Nouveau message', $sender->full_name . ': ' . mb_substr($preview, 0, 80), [
            'icon'       => 'chat',
            'action_url' => '/messages',
            'priority'   => self::PRIORITY_NORMAL,
            'sender_id'  => $sender->id,
            'image_url'  => $sender->avatar_url,
            'group_key'  => "msg_{$conversationId}",
            'data'       => ['conversation_id' => $conversationId],
        ]);
    }

    /**
     * New follower.
     */
    public function notifyFollow(string $userId, User $follower): ?UserNotification
    {
        return $this->send($userId, 'follow', 'Nouvel abonné', $follower->full_name . ' s\'est abonné à vous.', [
            'icon'       => 'person_add',
            'action_url' => '/seller/' . $follower->username,
            'priority'   => self::PRIORITY_NORMAL,
            'sender_id'  => $follower->id,
            'image_url'  => $follower->avatar_url,
            'group_key'  => "follow_{$userId}_day_" . now()->format('Y-m-d'),
        ]);
    }

    /**
     * Mutual follow → friendship.
     */
    public function notifyFriendship(string $userId, User $friend): ?UserNotification
    {
        return $this->send($userId, 'follow', 'Nouvel ami !', 'Vous et ' . $friend->full_name . ' êtes maintenant amis. Vous pouvez discuter !', [
            'icon'       => 'people',
            'action_url' => '/messages',
            'priority'   => self::PRIORITY_NORMAL,
            'sender_id'  => $friend->id,
            'image_url'  => $friend->avatar_url,
        ]);
    }

    /**
     * Product liked.
     */
    public function notifyLike(string $userId, User $liker, string $productSlug, string $productTitle): ?UserNotification
    {
        $count = UserNotification::where('user_id', $userId)
            ->where('group_key', "like_{$productSlug}")
            ->where('is_read', false)
            ->value('group_count') ?? 0;

        $body = $count > 0
            ? ($count + 1) . ' personnes ont aimé votre produit "' . mb_substr($productTitle, 0, 30) . '"'
            : $liker->full_name . ' a aimé votre produit "' . mb_substr($productTitle, 0, 30) . '"';

        return $this->send($userId, 'like', 'J\'aime', $body, [
            'icon'       => 'favorite',
            'action_url' => '/product/' . $productSlug,
            'priority'   => self::PRIORITY_LOW,
            'sender_id'  => $liker->id,
            'image_url'  => $liker->avatar_url,
            'group_key'  => "like_{$productSlug}",
        ]);
    }

    /**
     * New review received.
     */
    public function notifyReview(string $userId, User $reviewer, int $rating, string $comment): ?UserNotification
    {
        $stars = str_repeat('⭐', $rating);
        return $this->send($userId, 'review', 'Nouvel avis ' . $stars, $reviewer->full_name . ': "' . mb_substr($comment, 0, 60) . '"', [
            'icon'       => 'star',
            'action_url' => '/profile',
            'priority'   => self::PRIORITY_NORMAL,
            'sender_id'  => $reviewer->id,
            'image_url'  => $reviewer->avatar_url,
        ]);
    }

    /**
     * Transaction status update.
     */
    public function notifyTransaction(string $userId, string $status, string $transactionId, string $productTitle, float $amount): ?UserNotification
    {
        $labels = [
            'initiated'  => ['Nouvelle commande', "Commande pour \"{$productTitle}\" - " . number_format($amount, 0, ',', ' ') . " F"],
            'confirmed'  => ['Paiement confirmé', "Le paiement de " . number_format($amount, 0, ',', ' ') . " F pour \"{$productTitle}\" est confirmé."],
            'processing' => ['Commande en traitement', "Votre commande \"{$productTitle}\" est en cours de préparation."],
            'shipped'    => ['Commande expédiée', "Votre commande \"{$productTitle}\" a été expédiée !"],
            'delivered'  => ['Commande livrée', "Votre commande \"{$productTitle}\" a été livrée. Confirmez la réception."],
            'completed'  => ['Transaction terminée', "La transaction pour \"{$productTitle}\" est complète. Merci !"],
            'cancelled'  => ['Commande annulée', "La commande pour \"{$productTitle}\" a été annulée."],
            'disputed'   => ['Litige ouvert', "Un litige a été ouvert pour \"{$productTitle}\"."],
        ];

        $info = $labels[$status] ?? ['Mise à jour commande', "Statut de \"{$productTitle}\" mis à jour: {$status}"];

        return $this->send($userId, 'transaction', $info[0], $info[1], [
            'icon'       => $this->transactionIcon($status),
            'action_url' => '/transactions',
            'priority'   => self::PRIORITY_CRITICAL,
            'data'       => ['transaction_id' => $transactionId, 'status' => $status],
        ]);
    }

    /**
     * Admin notification to a user.
     */
    public function notifyAdmin(string $userId, string $title, string $body, ?string $actionUrl = null): ?UserNotification
    {
        return $this->send($userId, 'admin', $title, $body, [
            'icon'       => 'admin_panel_settings',
            'action_url' => $actionUrl ?? '/profile',
            'priority'   => self::PRIORITY_CRITICAL,
        ]);
    }

    /**
     * Negotiation / offer notification.
     */
    public function notifyNegotiation(string $userId, User $sender, string $action, string $productTitle, float $amount): ?UserNotification
    {
        $labels = [
            'proposed' => $sender->full_name . ' propose ' . number_format($amount, 0, ',', ' ') . ' F pour "' . mb_substr($productTitle, 0, 30) . '"',
            'accepted' => 'Votre offre de ' . number_format($amount, 0, ',', ' ') . ' F pour "' . mb_substr($productTitle, 0, 30) . '" a été acceptée !',
            'rejected' => 'Votre offre pour "' . mb_substr($productTitle, 0, 30) . '" a été refusée.',
            'counter'  => $sender->full_name . ' a fait une contre-offre de ' . number_format($amount, 0, ',', ' ') . ' F',
        ];

        return $this->send($userId, 'transaction', 'Négociation', $labels[$action] ?? 'Mise à jour de négociation', [
            'icon'       => 'local_offer',
            'action_url' => '/transactions',
            'priority'   => self::PRIORITY_NORMAL,
            'sender_id'  => $sender->id,
            'image_url'  => $sender->avatar_url,
        ]);
    }

    /**
     * Welcome notification for new users (first login).
     */
    public function notifyWelcome(User $user): ?UserNotification
    {
        // Check if already sent
        $exists = UserNotification::where('user_id', $user->id)
            ->where('type', 'welcome')
            ->exists();

        if ($exists) return null;

        return $this->send($user->id, 'welcome', 'Bienvenue sur QUINCH ! 🎉', 'Découvrez des milliers de produits, publiez vos articles et rejoignez la communauté. Commencez par compléter votre profil !', [
            'icon'       => 'waving_hand',
            'action_url' => '/profile/edit',
            'priority'   => self::PRIORITY_NORMAL,
        ]);
    }

    // ─── Helpers ─────────────────────────────────────────

    private function defaultIcon(string $type): string
    {
        return match ($type) {
            'message'     => 'chat',
            'follow'      => 'person_add',
            'like'        => 'favorite',
            'comment'     => 'comment',
            'review'      => 'star',
            'transaction' => 'receipt_long',
            'system'      => 'info',
            'admin'       => 'admin_panel_settings',
            'welcome'     => 'waving_hand',
            default       => 'notifications',
        };
    }

    private function transactionIcon(string $status): string
    {
        return match ($status) {
            'initiated'  => 'shopping_cart',
            'confirmed'  => 'check_circle',
            'processing' => 'pending',
            'shipped'    => 'local_shipping',
            'delivered'  => 'inventory',
            'completed'  => 'verified',
            'cancelled'  => 'cancel',
            'disputed'   => 'gavel',
            default      => 'receipt_long',
        };
    }
}
