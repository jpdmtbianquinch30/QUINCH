<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\UserFollow;
use App\Models\Conversation;
use App\Models\Message;
use App\Services\NotificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class FollowController extends Controller
{
    public function __construct(private NotificationService $notif) {}

    public function follow(Request $request, User $user): JsonResponse
    {
        $me = $request->user();
        if ($me->id === $user->id) {
            return response()->json(['message' => 'Vous ne pouvez pas vous suivre vous-même.'], 422);
        }

        $existing = UserFollow::where('follower_id', $me->id)->where('following_id', $user->id)->first();
        if ($existing) {
            return response()->json(['message' => 'Vous suivez déjà cet utilisateur.'], 422);
        }

        UserFollow::create(['follower_id' => $me->id, 'following_id' => $user->id]);

        // Check if this creates a MUTUAL follow (friendship)
        $isMutual = UserFollow::where('follower_id', $user->id)
            ->where('following_id', $me->id)
            ->exists();

        if ($isMutual) {
            // Notify BOTH users they are now friends
            $this->notif->notifyFriendship($user->id, $me);
            $this->notif->notifyFriendship($me->id, $user);

            // Auto-create a conversation with a system message
            $conversation = Conversation::where(function ($q) use ($me, $user) {
                $q->where('buyer_id', $me->id)->where('seller_id', $user->id);
            })->orWhere(function ($q) use ($me, $user) {
                $q->where('buyer_id', $user->id)->where('seller_id', $me->id);
            })->whereNull('product_id')->first();

            if (!$conversation) {
                $conversation = Conversation::create([
                    'buyer_id' => $me->id,
                    'seller_id' => $user->id,
                    'status' => 'active',
                    'last_message_at' => now(),
                ]);
            }

            // Send system message
            Message::create([
                'conversation_id' => $conversation->id,
                'sender_id' => $me->id,
                'body' => '🤝 Vous êtes maintenant amis! Vous pouvez discuter librement.',
                'type' => 'system',
            ]);

            $conversation->update(['last_message_at' => now()]);

            return response()->json([
                'following' => true,
                'is_mutual' => true,
                'message' => 'Vous êtes maintenant amis!',
                'conversation_id' => $conversation->id,
            ]);
        }

        // Regular follow notification
        $this->notif->notifyFollow($user->id, $me);

        return response()->json([
            'following' => true,
            'is_mutual' => false,
            'message' => 'Abonnement réussi.',
        ]);
    }

    public function unfollow(Request $request, User $user): JsonResponse
    {
        UserFollow::where('follower_id', $request->user()->id)->where('following_id', $user->id)->delete();
        return response()->json(['following' => false, 'message' => 'Désabonnement réussi.']);
    }

    /**
     * Get mutual friends (both follow each other).
     */
    public function friends(Request $request): JsonResponse
    {
        $userId = $request->user()->id;

        // Users I follow who also follow me back
        $friendIds = UserFollow::where('follower_id', $userId)
            ->whereIn('following_id', function ($q) use ($userId) {
                $q->select('follower_id')
                  ->from('user_follows')
                  ->where('following_id', $userId);
            })
            ->pluck('following_id');

        $friends = User::whereIn('id', $friendIds)
            ->select('id', 'full_name', 'username', 'avatar_url', 'trust_score', 'city')
            ->get();

        return response()->json(['friends' => $friends]);
    }

    /**
     * Check if two users are mutual friends.
     */
    public function isFriend(Request $request, User $user): JsonResponse
    {
        $userId = $request->user()->id;

        $iFollow = UserFollow::where('follower_id', $userId)->where('following_id', $user->id)->exists();
        $theyFollow = UserFollow::where('follower_id', $user->id)->where('following_id', $userId)->exists();

        return response()->json([
            'is_friend' => $iFollow && $theyFollow,
            'i_follow' => $iFollow,
            'they_follow' => $theyFollow,
        ]);
    }

    public function followers(Request $request, User $user): JsonResponse
    {
        $followers = UserFollow::where('following_id', $user->id)
            ->with('follower:id,full_name,username,avatar_url,trust_score')
            ->orderBy('created_at', 'desc')
            ->paginate(20);

        return response()->json($followers);
    }

    public function following(Request $request, User $user): JsonResponse
    {
        $following = UserFollow::where('follower_id', $user->id)
            ->with('following:id,full_name,username,avatar_url,trust_score')
            ->orderBy('created_at', 'desc')
            ->paginate(20);

        return response()->json($following);
    }

    public function myFollowers(Request $request): JsonResponse
    {
        return $this->followers($request, $request->user());
    }

    public function myFollowing(Request $request): JsonResponse
    {
        return $this->following($request, $request->user());
    }

    public function counts(Request $request, User $user): JsonResponse
    {
        $userId = $user->id;
        $authId = $request->user()?->id;

        $iFollow = $authId
            ? UserFollow::where('follower_id', $authId)->where('following_id', $userId)->exists()
            : false;
        $theyFollow = $authId
            ? UserFollow::where('follower_id', $userId)->where('following_id', $authId)->exists()
            : false;

        return response()->json([
            'followers' => UserFollow::where('following_id', $userId)->count(),
            'following' => UserFollow::where('follower_id', $userId)->count(),
            'is_following' => $iFollow,
            'is_mutual' => $iFollow && $theyFollow,
        ]);
    }
}
