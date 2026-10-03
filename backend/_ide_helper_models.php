<?php

// @formatter:off
// phpcs:ignoreFile
/**
 * A helper file for your Eloquent Models
 * Copy the phpDocs from this file to the correct Model,
 * And remove them from this file, to prevent double declarations.
 *
 * @author Barry vd. Heuvel <barryvdh@gmail.com>
 */


namespace App\Models{
/**
 * @property string $id
 * @property string $admin_id
 * @property string $action
 * @property string|null $target_type
 * @property string|null $target_id
 * @property array<array-key, mixed>|null $metadata
 * @property string|null $ip_address
 * @property string $severity
 * @property \Illuminate\Support\Carbon|null $created_at
 * @property \Illuminate\Support\Carbon|null $updated_at
 * @property-read \App\Models\User $admin
 * @method static \Illuminate\Database\Eloquent\Builder<static>|AdminActionLog newModelQuery()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|AdminActionLog newQuery()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|AdminActionLog query()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|AdminActionLog whereAction($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|AdminActionLog whereAdminId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|AdminActionLog whereCreatedAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|AdminActionLog whereId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|AdminActionLog whereIpAddress($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|AdminActionLog whereMetadata($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|AdminActionLog whereSeverity($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|AdminActionLog whereTargetId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|AdminActionLog whereTargetType($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|AdminActionLog whereUpdatedAt($value)
 */
	class AdminActionLog extends \Eloquent {}
}

namespace App\Models{
/**
 * @property int $id
 * @property string|null $user_id
 * @property string $action_type
 * @property string $entity_type
 * @property string|null $entity_id
 * @property string|null $ip_address
 * @property string|null $user_agent
 * @property array<array-key, mixed>|null $location_data
 * @property array<array-key, mixed>|null $old_values
 * @property array<array-key, mixed>|null $new_values
 * @property string|null $changes
 * @property string $severity
 * @property \Illuminate\Support\Carbon $created_at
 * @property-read \App\Models\User|null $user
 * @method static \Illuminate\Database\Eloquent\Builder<static>|AuditLog critical()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|AuditLog forUser(string $userId)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|AuditLog newModelQuery()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|AuditLog newQuery()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|AuditLog query()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|AuditLog recent(int $days = 7)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|AuditLog whereActionType($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|AuditLog whereChanges($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|AuditLog whereCreatedAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|AuditLog whereEntityId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|AuditLog whereEntityType($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|AuditLog whereId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|AuditLog whereIpAddress($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|AuditLog whereLocationData($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|AuditLog whereNewValues($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|AuditLog whereOldValues($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|AuditLog whereSeverity($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|AuditLog whereUserAgent($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|AuditLog whereUserId($value)
 */
	class AuditLog extends \Eloquent {}
}

namespace App\Models{
/**
 * @property string $id
 * @property string $ip_address
 * @property string|null $reason
 * @property string|null $banned_by
 * @property \Illuminate\Support\Carbon|null $created_at
 * @property \Illuminate\Support\Carbon|null $updated_at
 * @property-read \App\Models\User|null $bannedBy
 * @method static \Illuminate\Database\Eloquent\Builder<static>|BannedIp newModelQuery()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|BannedIp newQuery()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|BannedIp query()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|BannedIp whereBannedBy($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|BannedIp whereCreatedAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|BannedIp whereId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|BannedIp whereIpAddress($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|BannedIp whereReason($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|BannedIp whereUpdatedAt($value)
 */
	class BannedIp extends \Eloquent {}
}

namespace App\Models{
/**
 * @property string $id
 * @property string $user_id
 * @property string $product_id
 * @property int $quantity
 * @property float $price_at_add
 * @property \Illuminate\Support\Carbon|null $reserved_until
 * @property \Illuminate\Support\Carbon|null $created_at
 * @property \Illuminate\Support\Carbon|null $updated_at
 * @property-read \App\Models\Product $product
 * @property-read \App\Models\User $user
 * @method static \Illuminate\Database\Eloquent\Builder<static>|CartItem newModelQuery()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|CartItem newQuery()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|CartItem query()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|CartItem whereCreatedAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|CartItem whereId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|CartItem wherePriceAtAdd($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|CartItem whereProductId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|CartItem whereQuantity($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|CartItem whereReservedUntil($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|CartItem whereUpdatedAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|CartItem whereUserId($value)
 */
	class CartItem extends \Eloquent {}
}

namespace App\Models{
/**
 * @property string $id
 * @property string $name
 * @property string $slug
 * @property string|null $icon
 * @property string|null $description
 * @property string|null $parent_id
 * @property int $sort_order
 * @property bool $is_active
 * @property \Illuminate\Support\Carbon|null $created_at
 * @property \Illuminate\Support\Carbon|null $updated_at
 * @property-read \Illuminate\Database\Eloquent\Collection<int, Category> $children
 * @property-read int|null $children_count
 * @property-read Category|null $parent
 * @property-read \Illuminate\Database\Eloquent\Collection<int, \App\Models\Product> $products
 * @property-read int|null $products_count
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Category active()
 * @method static \Database\Factories\CategoryFactory factory($count = null, $state = [])
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Category newModelQuery()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Category newQuery()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Category query()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Category roots()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Category whereCreatedAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Category whereDescription($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Category whereIcon($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Category whereId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Category whereIsActive($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Category whereName($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Category whereParentId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Category whereSlug($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Category whereSortOrder($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Category whereUpdatedAt($value)
 */
	class Category extends \Eloquent {}
}

namespace App\Models{
/**
 * @property string $id
 * @property string $buyer_id
 * @property string $seller_id
 * @property string|null $product_id
 * @property string $status
 * @property \Illuminate\Support\Carbon|null $last_message_at
 * @property \Illuminate\Support\Carbon|null $created_at
 * @property \Illuminate\Support\Carbon|null $updated_at
 * @property-read \App\Models\User $buyer
 * @property-read \App\Models\Message|null $lastMessage
 * @property-read \Illuminate\Database\Eloquent\Collection<int, \App\Models\Message> $messages
 * @property-read int|null $messages_count
 * @property-read \App\Models\Product|null $product
 * @property-read \Illuminate\Database\Eloquent\Collection<int, \App\Models\ConversationProductTag> $productTags
 * @property-read int|null $product_tags_count
 * @property-read \App\Models\User $seller
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Conversation newModelQuery()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Conversation newQuery()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Conversation query()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Conversation whereBuyerId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Conversation whereCreatedAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Conversation whereId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Conversation whereLastMessageAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Conversation whereProductId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Conversation whereSellerId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Conversation whereStatus($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Conversation whereUpdatedAt($value)
 */
	class Conversation extends \Eloquent {}
}

namespace App\Models{
/**
 * @property string $id
 * @property string $conversation_id
 * @property string $product_id
 * @property string|null $tagged_by
 * @property string|null $transaction_id
 * @property \Illuminate\Support\Carbon|null $created_at
 * @property \Illuminate\Support\Carbon|null $updated_at
 * @property-read \App\Models\Conversation $conversation
 * @property-read \App\Models\Product $product
 * @property-read \App\Models\User|null $taggedBy
 * @property-read \App\Models\Transaction|null $transaction
 * @method static \Illuminate\Database\Eloquent\Builder<static>|ConversationProductTag newModelQuery()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|ConversationProductTag newQuery()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|ConversationProductTag query()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|ConversationProductTag whereConversationId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|ConversationProductTag whereCreatedAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|ConversationProductTag whereId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|ConversationProductTag whereProductId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|ConversationProductTag whereTaggedBy($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|ConversationProductTag whereTransactionId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|ConversationProductTag whereUpdatedAt($value)
 */
	class ConversationProductTag extends \Eloquent {}
}

namespace App\Models{
/**
 * @property string $id
 * @property string $user_id
 * @property string $name
 * @property bool $is_public
 * @property \Illuminate\Support\Carbon|null $created_at
 * @property \Illuminate\Support\Carbon|null $updated_at
 * @property-read \Illuminate\Database\Eloquent\Collection<int, \App\Models\FavoriteItem> $items
 * @property-read int|null $items_count
 * @property-read \App\Models\User $user
 * @method static \Illuminate\Database\Eloquent\Builder<static>|FavoriteCollection newModelQuery()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|FavoriteCollection newQuery()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|FavoriteCollection query()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|FavoriteCollection whereCreatedAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|FavoriteCollection whereId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|FavoriteCollection whereIsPublic($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|FavoriteCollection whereName($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|FavoriteCollection whereUpdatedAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|FavoriteCollection whereUserId($value)
 */
	class FavoriteCollection extends \Eloquent {}
}

namespace App\Models{
/**
 * @property string $id
 * @property string $user_id
 * @property string $product_id
 * @property string|null $collection_id
 * @property float|null $price_at_save
 * @property \Illuminate\Support\Carbon|null $created_at
 * @property \Illuminate\Support\Carbon|null $updated_at
 * @property-read \App\Models\FavoriteCollection|null $collection
 * @property-read \App\Models\Product $product
 * @property-read \App\Models\User $user
 * @method static \Illuminate\Database\Eloquent\Builder<static>|FavoriteItem newModelQuery()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|FavoriteItem newQuery()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|FavoriteItem query()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|FavoriteItem whereCollectionId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|FavoriteItem whereCreatedAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|FavoriteItem whereId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|FavoriteItem wherePriceAtSave($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|FavoriteItem whereProductId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|FavoriteItem whereUpdatedAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|FavoriteItem whereUserId($value)
 */
	class FavoriteItem extends \Eloquent {}
}

namespace App\Models{
/**
 * @property int $id
 * @property string|null $user_id
 * @property string $detection_type
 * @property float $confidence_score
 * @property array<array-key, mixed> $evidence
 * @property string $status
 * @property string $action_taken
 * @property string|null $reviewed_by
 * @property \Illuminate\Support\Carbon|null $reviewed_at
 * @property \Illuminate\Support\Carbon|null $created_at
 * @property \Illuminate\Support\Carbon|null $updated_at
 * @property-read \App\Models\User|null $reviewer
 * @property-read \App\Models\User|null $user
 * @method static \Illuminate\Database\Eloquent\Builder<static>|FraudDetection highConfidence()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|FraudDetection newModelQuery()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|FraudDetection newQuery()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|FraudDetection pendingReview()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|FraudDetection query()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|FraudDetection whereActionTaken($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|FraudDetection whereConfidenceScore($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|FraudDetection whereCreatedAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|FraudDetection whereDetectionType($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|FraudDetection whereEvidence($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|FraudDetection whereId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|FraudDetection whereReviewedAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|FraudDetection whereReviewedBy($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|FraudDetection whereStatus($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|FraudDetection whereUpdatedAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|FraudDetection whereUserId($value)
 */
	class FraudDetection extends \Eloquent {}
}

namespace App\Models{
/**
 * @property string $id
 * @property string $conversation_id
 * @property string $sender_id
 * @property string $body
 * @property string $type
 * @property array<array-key, mixed>|null $metadata
 * @property bool $is_read
 * @property \Illuminate\Support\Carbon|null $read_at
 * @property \Illuminate\Support\Carbon|null $created_at
 * @property \Illuminate\Support\Carbon|null $updated_at
 * @property-read \App\Models\Conversation $conversation
 * @property-read \App\Models\User $sender
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Message newModelQuery()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Message newQuery()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Message query()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Message whereBody($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Message whereConversationId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Message whereCreatedAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Message whereId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Message whereIsRead($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Message whereMetadata($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Message whereReadAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Message whereSenderId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Message whereType($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Message whereUpdatedAt($value)
 */
	class Message extends \Eloquent {}
}

namespace App\Models{
/**
 * @property string $id
 * @property string $buyer_id
 * @property string $seller_id
 * @property string $product_id
 * @property float $proposed_price
 * @property float|null $counter_price
 * @property string $status
 * @property string|null $buyer_message
 * @property string|null $seller_message
 * @property \Illuminate\Support\Carbon $expires_at
 * @property \Illuminate\Support\Carbon|null $created_at
 * @property \Illuminate\Support\Carbon|null $updated_at
 * @property-read \App\Models\User $buyer
 * @property-read \App\Models\Product $product
 * @property-read \App\Models\User $seller
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Negotiation newModelQuery()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Negotiation newQuery()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Negotiation query()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Negotiation whereBuyerId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Negotiation whereBuyerMessage($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Negotiation whereCounterPrice($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Negotiation whereCreatedAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Negotiation whereExpiresAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Negotiation whereId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Negotiation whereProductId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Negotiation whereProposedPrice($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Negotiation whereSellerId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Negotiation whereSellerMessage($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Negotiation whereStatus($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Negotiation whereUpdatedAt($value)
 */
	class Negotiation extends \Eloquent {}
}

namespace App\Models{
/**
 * @property string $id
 * @property string $user_id
 * @property string $type
 * @property bool $push_enabled
 * @property bool $in_app_enabled
 * @property bool $email_enabled
 * @property \Illuminate\Support\Carbon|null $created_at
 * @property \Illuminate\Support\Carbon|null $updated_at
 * @property-read \App\Models\User $user
 * @method static \Illuminate\Database\Eloquent\Builder<static>|NotificationPreference newModelQuery()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|NotificationPreference newQuery()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|NotificationPreference query()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|NotificationPreference whereCreatedAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|NotificationPreference whereEmailEnabled($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|NotificationPreference whereId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|NotificationPreference whereInAppEnabled($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|NotificationPreference wherePushEnabled($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|NotificationPreference whereType($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|NotificationPreference whereUpdatedAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|NotificationPreference whereUserId($value)
 */
	class NotificationPreference extends \Eloquent {}
}

namespace App\Models{
/**
 * @property string $id
 * @property string $user_id
 * @property string $plan
 * @property float $amount
 * @property string $currency
 * @property string $status
 * @property string $payment_method
 * @property string|null $payment_gateway_id
 * @property \Illuminate\Support\Carbon|null $starts_at
 * @property \Illuminate\Support\Carbon|null $expires_at
 * @property \Illuminate\Support\Carbon|null $created_at
 * @property \Illuminate\Support\Carbon|null $updated_at
 * @property-read \App\Models\User $user
 * @method static \Illuminate\Database\Eloquent\Builder<static>|PremiumSubscription active()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|PremiumSubscription newModelQuery()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|PremiumSubscription newQuery()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|PremiumSubscription pending()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|PremiumSubscription query()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|PremiumSubscription whereAmount($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|PremiumSubscription whereCreatedAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|PremiumSubscription whereCurrency($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|PremiumSubscription whereExpiresAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|PremiumSubscription whereId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|PremiumSubscription wherePaymentGatewayId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|PremiumSubscription wherePaymentMethod($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|PremiumSubscription wherePlan($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|PremiumSubscription whereStartsAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|PremiumSubscription whereStatus($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|PremiumSubscription whereUpdatedAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|PremiumSubscription whereUserId($value)
 */
	class PremiumSubscription extends \Eloquent {}
}

namespace App\Models{
/**
 * @property string $id
 * @property string $user_id
 * @property string $title
 * @property string $slug
 * @property string|null $description
 * @property string $category_id
 * @property float $price
 * @property string $currency
 * @property int $stock_quantity
 * @property string $condition
 * @property bool $is_negotiable
 * @property string $status
 * @property string|null $video_id
 * @property array<array-key, mixed>|null $metadata
 * @property array $images
 * @property int $view_count
 * @property int $like_count
 * @property int $share_count
 * @property \Illuminate\Support\Carbon|null $expires_at
 * @property \Illuminate\Support\Carbon|null $created_at
 * @property \Illuminate\Support\Carbon|null $updated_at
 * @property string $type
 * @property array<array-key, mixed>|null $payment_methods
 * @property string $delivery_option
 * @property int $delivery_fee
 * @property string|null $poster_url
 * @property int $listing_fee_amount
 * @property string $listing_fee_status
 * @property string|null $listing_fee_gateway_id
 * @property-read \App\Models\Category $category
 * @property-read string $formatted_price
 * @property-read string|null $poster_full_url
 * @property-read \Illuminate\Database\Eloquent\Collection<int, \App\Models\User> $likedByUsers
 * @property-read int|null $liked_by_users_count
 * @property-read \Illuminate\Database\Eloquent\Collection<int, \App\Models\User> $savedByUsers
 * @property-read int|null $saved_by_users_count
 * @property-read \Illuminate\Database\Eloquent\Collection<int, \App\Models\Transaction> $transactions
 * @property-read int|null $transactions_count
 * @property-read \App\Models\User $user
 * @property-read \App\Models\ProductVideo|null $video
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Product active()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Product available()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Product byCategory(string $categoryId)
 * @method static \Database\Factories\ProductFactory factory($count = null, $state = [])
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Product newModelQuery()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Product newQuery()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Product priceRange(?float $min, ?float $max)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Product query()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Product search(string $term)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Product tieredRank()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Product visible()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Product whereCategoryId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Product whereCondition($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Product whereCreatedAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Product whereCurrency($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Product whereDeliveryFee($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Product whereDeliveryOption($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Product whereDescription($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Product whereExpiresAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Product whereId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Product whereImages($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Product whereIsNegotiable($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Product whereLikeCount($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Product whereListingFeeAmount($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Product whereListingFeeGatewayId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Product whereListingFeeStatus($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Product whereMetadata($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Product wherePaymentMethods($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Product wherePosterUrl($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Product wherePrice($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Product whereShareCount($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Product whereSlug($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Product whereStatus($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Product whereStockQuantity($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Product whereTitle($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Product whereType($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Product whereUpdatedAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Product whereUserId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Product whereVideoId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Product whereViewCount($value)
 */
	class Product extends \Eloquent {}
}

namespace App\Models{
/**
 * @property string $id
 * @property string $reporter_id
 * @property string $product_id
 * @property string $reason
 * @property string|null $description
 * @property string $status
 * @property string|null $reviewed_by
 * @property string|null $admin_notes
 * @property \Illuminate\Support\Carbon|null $created_at
 * @property \Illuminate\Support\Carbon|null $updated_at
 * @property-read \App\Models\Product $product
 * @property-read \App\Models\User $reporter
 * @property-read \App\Models\User|null $reviewer
 * @method static \Illuminate\Database\Eloquent\Builder<static>|ProductReport newModelQuery()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|ProductReport newQuery()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|ProductReport pending()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|ProductReport query()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|ProductReport whereAdminNotes($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|ProductReport whereCreatedAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|ProductReport whereDescription($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|ProductReport whereId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|ProductReport whereProductId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|ProductReport whereReason($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|ProductReport whereReporterId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|ProductReport whereReviewedBy($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|ProductReport whereStatus($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|ProductReport whereUpdatedAt($value)
 */
	class ProductReport extends \Eloquent {}
}

namespace App\Models{
/**
 * @property string $id
 * @property string $user_id
 * @property string $video_path
 * @property string|null $thumbnail_path
 * @property int|null $duration_seconds
 * @property string|null $format
 * @property int|null $size_bytes
 * @property string|null $hash_sha256
 * @property string $processing_status
 * @property string $moderation_status
 * @property int $view_count
 * @property float $engagement_score
 * @property \Illuminate\Support\Carbon|null $created_at
 * @property \Illuminate\Support\Carbon|null $updated_at
 * @property string|null $resolution
 * @property int|null $width
 * @property int|null $height
 * @property string|null $quality_label
 * @property string $source
 * @property-read string|null $thumbnail_url
 * @property-read string|null $video_absolute_url
 * @property-read string|null $video_storage_url
 * @property-read string|null $video_url
 * @property-read \App\Models\Product|null $product
 * @property-read \App\Models\User $user
 * @method static \Illuminate\Database\Eloquent\Builder<static>|ProductVideo approved()
 * @method static \Database\Factories\ProductVideoFactory factory($count = null, $state = [])
 * @method static \Illuminate\Database\Eloquent\Builder<static>|ProductVideo newModelQuery()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|ProductVideo newQuery()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|ProductVideo pending()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|ProductVideo query()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|ProductVideo whereCreatedAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|ProductVideo whereDurationSeconds($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|ProductVideo whereEngagementScore($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|ProductVideo whereFormat($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|ProductVideo whereHashSha256($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|ProductVideo whereHeight($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|ProductVideo whereId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|ProductVideo whereModerationStatus($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|ProductVideo whereProcessingStatus($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|ProductVideo whereQualityLabel($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|ProductVideo whereResolution($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|ProductVideo whereSizeBytes($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|ProductVideo whereSource($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|ProductVideo whereThumbnailPath($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|ProductVideo whereUpdatedAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|ProductVideo whereUserId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|ProductVideo whereVideoPath($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|ProductVideo whereViewCount($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|ProductVideo whereWidth($value)
 */
	class ProductVideo extends \Eloquent {}
}

namespace App\Models{
/**
 * @property string $id
 * @property string $user_id
 * @property string $category
 * @property string $description
 * @property string $status
 * @property string|null $reviewed_by
 * @property string|null $admin_notes
 * @property \Illuminate\Support\Carbon|null $created_at
 * @property \Illuminate\Support\Carbon|null $updated_at
 * @property-read \App\Models\User|null $reviewer
 * @property-read \App\Models\User $user
 * @method static \Illuminate\Database\Eloquent\Builder<static>|SupportTicket newModelQuery()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|SupportTicket newQuery()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|SupportTicket pending()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|SupportTicket query()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|SupportTicket whereAdminNotes($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|SupportTicket whereCategory($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|SupportTicket whereCreatedAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|SupportTicket whereDescription($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|SupportTicket whereId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|SupportTicket whereReviewedBy($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|SupportTicket whereStatus($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|SupportTicket whereUpdatedAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|SupportTicket whereUserId($value)
 */
	class SupportTicket extends \Eloquent {}
}

namespace App\Models{
/**
 * @property string $id
 * @property string $buyer_id
 * @property string $seller_id
 * @property string $product_id
 * @property float $amount
 * @property string $currency
 * @property string|null $payment_method
 * @property string $payment_status
 * @property string|null $payment_gateway_id
 * @property string $security_check
 * @property string|null $delivery_type
 * @property array<array-key, mixed>|null $delivery_address
 * @property float $transaction_fee
 * @property float $risk_score
 * @property int $payment_failure_count
 * @property \Illuminate\Support\Carbon|null $completed_at
 * @property \Illuminate\Support\Carbon|null $created_at
 * @property \Illuminate\Support\Carbon|null $updated_at
 * @property int $quantity
 * @property \Illuminate\Support\Carbon|null $paid_at
 * @property string $order_status
 * @property-read \App\Models\User $buyer
 * @property-read string $formatted_amount
 * @property-read \App\Models\Product $product
 * @property-read \App\Models\User $seller
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Transaction completed()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Transaction newModelQuery()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Transaction newQuery()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Transaction pending()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Transaction query()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Transaction suspicious()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Transaction whereAmount($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Transaction whereBuyerId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Transaction whereCompletedAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Transaction whereCreatedAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Transaction whereCurrency($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Transaction whereDeliveryAddress($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Transaction whereDeliveryType($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Transaction whereId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Transaction whereOrderStatus($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Transaction wherePaidAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Transaction wherePaymentFailureCount($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Transaction wherePaymentGatewayId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Transaction wherePaymentMethod($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Transaction wherePaymentStatus($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Transaction whereProductId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Transaction whereQuantity($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Transaction whereRiskScore($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Transaction whereSecurityCheck($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Transaction whereSellerId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Transaction whereTransactionFee($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|Transaction whereUpdatedAt($value)
 */
	class Transaction extends \Eloquent {}
}

namespace App\Models{
/**
 * @property string $id
 * @property string|null $phone_number
 * @property string|null $email
 * @property string|null $username
 * @property string|null $full_name
 * @property string $password
 * @property string|null $avatar_url
 * @property float $trust_score
 * @property string $kyc_status
 * @property array<array-key, mixed>|null $kyc_data
 * @property string|null $city
 * @property string|null $region
 * @property float|null $latitude
 * @property float|null $longitude
 * @property bool $is_seller
 * @property bool $is_buyer
 * @property string $role
 * @property string $security_level
 * @property string $account_status
 * @property \Illuminate\Support\Carbon|null $last_suspicious_activity
 * @property string|null $otp_code
 * @property \Illuminate\Support\Carbon|null $otp_expires_at
 * @property bool $phone_verified
 * @property array<array-key, mixed>|null $preferences
 * @property bool $onboarding_completed
 * @property string|null $device_fingerprint
 * @property string|null $remember_token
 * @property \Illuminate\Support\Carbon|null $created_at
 * @property \Illuminate\Support\Carbon|null $updated_at
 * @property string|null $google_id
 * @property string|null $cover_url
 * @property string|null $bio
 * @property string|null $pending_phone_number
 * @property bool $is_premium
 * @property string|null $premium_plan
 * @property \Illuminate\Support\Carbon|null $premium_expires_at
 * @property string|null $ban_reason
 * @property string|null $banned_at
 * @property string|null $website
 * @property array<array-key, mixed>|null $seller_policies
 * @property \Illuminate\Support\Carbon|null $last_seen_at
 * @property bool $ranking_opt_in
 * @property bool $ranking_anonymous
 * @property int $profile_views_count
 * @property-read \Illuminate\Database\Eloquent\Collection<int, \App\Models\UserBadge> $badges
 * @property-read int|null $badges_count
 * @property-read \Illuminate\Database\Eloquent\Collection<int, User> $blockedUsers
 * @property-read int|null $blocked_users_count
 * @property-read \Illuminate\Database\Eloquent\Collection<int, \App\Models\UserFollow> $followers
 * @property-read int|null $followers_count
 * @property-read \Illuminate\Database\Eloquent\Collection<int, \App\Models\UserFollow> $following
 * @property-read int|null $following_count
 * @property-read int $account_age_days
 * @property-read string $trust_badge
 * @property-read string $trust_level
 * @property-read mixed $is_online
 * @property-read \Illuminate\Database\Eloquent\Collection<int, \App\Models\Product> $likedProducts
 * @property-read int|null $liked_products_count
 * @property-read \Illuminate\Notifications\DatabaseNotificationCollection<int, \Illuminate\Notifications\DatabaseNotification> $notifications
 * @property-read int|null $notifications_count
 * @property-read \Illuminate\Database\Eloquent\Collection<int, \App\Models\PremiumSubscription> $premiumSubscriptions
 * @property-read int|null $premium_subscriptions_count
 * @property-read \Illuminate\Database\Eloquent\Collection<int, \App\Models\Product> $products
 * @property-read int|null $products_count
 * @property-read \Illuminate\Database\Eloquent\Collection<int, \App\Models\Transaction> $purchasedTransactions
 * @property-read int|null $purchased_transactions_count
 * @property-read \Illuminate\Database\Eloquent\Collection<int, \App\Models\UserReport> $reportsMade
 * @property-read int|null $reports_made_count
 * @property-read \Illuminate\Database\Eloquent\Collection<int, \App\Models\UserReport> $reportsReceived
 * @property-read int|null $reports_received_count
 * @property-read \Illuminate\Database\Eloquent\Collection<int, \App\Models\UserReview> $reviewsGiven
 * @property-read int|null $reviews_given_count
 * @property-read \Illuminate\Database\Eloquent\Collection<int, \App\Models\UserReview> $reviewsReceived
 * @property-read int|null $reviews_received_count
 * @property-read \Illuminate\Database\Eloquent\Collection<int, \App\Models\Product> $savedProducts
 * @property-read int|null $saved_products_count
 * @property-read \Illuminate\Database\Eloquent\Collection<int, \App\Models\Transaction> $soldTransactions
 * @property-read int|null $sold_transactions_count
 * @property-read \Illuminate\Database\Eloquent\Collection<int, \Laravel\Sanctum\PersonalAccessToken> $tokens
 * @property-read int|null $tokens_count
 * @property-read \Illuminate\Database\Eloquent\Collection<int, \App\Models\ProductVideo> $videos
 * @property-read int|null $videos_count
 * @method static \Illuminate\Database\Eloquent\Builder<static>|User active()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|User admins()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|User clients()
 * @method static \Database\Factories\UserFactory factory($count = null, $state = [])
 * @method static \Illuminate\Database\Eloquent\Builder<static>|User newModelQuery()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|User newQuery()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|User query()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|User verified()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|User whereAccountStatus($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|User whereAvatarUrl($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|User whereBanReason($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|User whereBannedAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|User whereBio($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|User whereCity($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|User whereCoverUrl($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|User whereCreatedAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|User whereDeviceFingerprint($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|User whereEmail($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|User whereFullName($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|User whereGoogleId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|User whereId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|User whereIsBuyer($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|User whereIsPremium($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|User whereIsSeller($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|User whereKycData($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|User whereKycStatus($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|User whereLastSeenAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|User whereLastSuspiciousActivity($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|User whereLatitude($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|User whereLongitude($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|User whereOnboardingCompleted($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|User whereOtpCode($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|User whereOtpExpiresAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|User wherePassword($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|User wherePendingPhoneNumber($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|User wherePhoneNumber($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|User wherePhoneVerified($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|User wherePreferences($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|User wherePremiumExpiresAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|User wherePremiumPlan($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|User whereProfileViewsCount($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|User whereRankingAnonymous($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|User whereRankingOptIn($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|User whereRegion($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|User whereRememberToken($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|User whereRole($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|User whereSecurityLevel($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|User whereSellerPolicies($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|User whereTrustScore($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|User whereUpdatedAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|User whereUsername($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|User whereWebsite($value)
 */
	class User extends \Eloquent {}
}

namespace App\Models{
/**
 * @property string $id
 * @property string $user_id
 * @property string $badge_type
 * @property string|null $badge_level
 * @property string|null $awarded_by
 * @property string|null $reason
 * @property \Illuminate\Support\Carbon|null $expires_at
 * @property \Illuminate\Support\Carbon|null $created_at
 * @property \Illuminate\Support\Carbon|null $updated_at
 * @property-read \App\Models\User|null $awardedBy
 * @property-read \App\Models\User $user
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserBadge active()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserBadge newModelQuery()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserBadge newQuery()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserBadge query()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserBadge whereAwardedBy($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserBadge whereBadgeLevel($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserBadge whereBadgeType($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserBadge whereCreatedAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserBadge whereExpiresAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserBadge whereId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserBadge whereReason($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserBadge whereUpdatedAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserBadge whereUserId($value)
 */
	class UserBadge extends \Eloquent {}
}

namespace App\Models{
/**
 * @property string $follower_id
 * @property string $following_id
 * @property bool $notifications_enabled
 * @property \Illuminate\Support\Carbon|null $created_at
 * @property \Illuminate\Support\Carbon|null $updated_at
 * @property-read \App\Models\User $follower
 * @property-read \App\Models\User $following
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserFollow newModelQuery()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserFollow newQuery()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserFollow query()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserFollow whereCreatedAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserFollow whereFollowerId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserFollow whereFollowingId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserFollow whereNotificationsEnabled($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserFollow whereUpdatedAt($value)
 */
	class UserFollow extends \Eloquent {}
}

namespace App\Models{
/**
 * @property string $id
 * @property string $user_id
 * @property string $type
 * @property string $title
 * @property string $body
 * @property string|null $icon
 * @property string|null $action_url
 * @property array<array-key, mixed>|null $data
 * @property bool $is_read
 * @property \Illuminate\Support\Carbon|null $read_at
 * @property \Illuminate\Support\Carbon|null $created_at
 * @property \Illuminate\Support\Carbon|null $updated_at
 * @property string|null $group_key
 * @property int $group_count
 * @property string $priority
 * @property string|null $image_url
 * @property string|null $sender_id
 * @property-read \App\Models\User|null $sender
 * @property-read \App\Models\User $user
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserNotification critical()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserNotification forTab(string $tab)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserNotification newModelQuery()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserNotification newQuery()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserNotification ofType(string $type)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserNotification query()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserNotification unread()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserNotification whereActionUrl($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserNotification whereBody($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserNotification whereCreatedAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserNotification whereData($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserNotification whereGroupCount($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserNotification whereGroupKey($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserNotification whereIcon($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserNotification whereId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserNotification whereImageUrl($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserNotification whereIsRead($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserNotification wherePriority($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserNotification whereReadAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserNotification whereSenderId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserNotification whereTitle($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserNotification whereType($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserNotification whereUpdatedAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserNotification whereUserId($value)
 */
	class UserNotification extends \Eloquent {}
}

namespace App\Models{
/**
 * @property string $id
 * @property string $reporter_id
 * @property string $reported_user_id
 * @property string $reason
 * @property string|null $description
 * @property string $status
 * @property string|null $reviewed_by
 * @property string|null $admin_notes
 * @property \Illuminate\Support\Carbon|null $created_at
 * @property \Illuminate\Support\Carbon|null $updated_at
 * @property-read \App\Models\User $reportedUser
 * @property-read \App\Models\User $reporter
 * @property-read \App\Models\User|null $reviewer
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserReport newModelQuery()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserReport newQuery()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserReport pending()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserReport query()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserReport whereAdminNotes($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserReport whereCreatedAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserReport whereDescription($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserReport whereId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserReport whereReason($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserReport whereReportedUserId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserReport whereReporterId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserReport whereReviewedBy($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserReport whereStatus($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserReport whereUpdatedAt($value)
 */
	class UserReport extends \Eloquent {}
}

namespace App\Models{
/**
 * @property string $id
 * @property string $reviewer_id
 * @property string $seller_id
 * @property string|null $transaction_id
 * @property int $rating
 * @property string|null $comment
 * @property float|null $delivery_rating
 * @property float|null $communication_rating
 * @property float|null $accuracy_rating
 * @property string|null $seller_response
 * @property \Illuminate\Support\Carbon|null $seller_responded_at
 * @property \Illuminate\Support\Carbon|null $created_at
 * @property \Illuminate\Support\Carbon|null $updated_at
 * @property-read \App\Models\User $reviewer
 * @property-read \App\Models\User $seller
 * @property-read \App\Models\Transaction|null $transaction
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserReview newModelQuery()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserReview newQuery()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserReview query()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserReview whereAccuracyRating($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserReview whereComment($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserReview whereCommunicationRating($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserReview whereCreatedAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserReview whereDeliveryRating($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserReview whereId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserReview whereRating($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserReview whereReviewerId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserReview whereSellerId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserReview whereSellerRespondedAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserReview whereSellerResponse($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserReview whereTransactionId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|UserReview whereUpdatedAt($value)
 */
	class UserReview extends \Eloquent {}
}

