<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Conversation;
use App\Models\Message;
use App\Services\NotificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class ConversationController extends Controller
{
    public function __construct(private NotificationService $notif) {}

    public function index(Request $request): JsonResponse
    {
        $userId = $request->user()->id;

        $conversations = Conversation::where('buyer_id', $userId)
            ->orWhere('seller_id', $userId)
            ->with(['buyer:id,full_name,avatar_url,username', 'seller:id,full_name,avatar_url,username', 'product:id,title,slug,price', 'lastMessage'])
            ->orderBy('last_message_at', 'desc')
            ->paginate(20);

        $conversations->getCollection()->transform(function ($conv) use ($userId) {
            $conv->unread_count = $conv->unreadCountFor($userId);
            $conv->other_user = $conv->buyer_id === $userId ? $conv->seller : $conv->buyer;
            return $conv;
        });

        return response()->json($conversations);
    }

    public function start(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'seller_id' => 'required|exists:users,id',
            'product_id' => 'nullable|exists:products,id',
            'message' => 'nullable|string|max:1000',
        ]);

        $userId = $request->user()->id;
        if ((string)$userId === (string)$validated['seller_id']) {
            return response()->json(['message' => 'Vous ne pouvez pas vous contacter vous-même.'], 422);
        }

        // Find existing conversation between these two users (in either direction)
        $conversation = Conversation::where(function ($q) use ($userId, $validated) {
                $q->where('buyer_id', $userId)
                  ->where('seller_id', $validated['seller_id']);
            })
            ->orWhere(function ($q) use ($userId, $validated) {
                $q->where('buyer_id', $validated['seller_id'])
                  ->where('seller_id', $userId);
            })
            ->first();

        if (!$conversation) {
            $conversation = Conversation::create([
                'buyer_id' => $userId,
                'seller_id' => $validated['seller_id'],
                'product_id' => $validated['product_id'] ?? null,
                'status' => 'active',
                'last_message_at' => now(),
            ]);
        }

        $message = null;
        if (!empty($validated['message'])) {
            $message = Message::create([
                'conversation_id' => $conversation->id,
                'sender_id' => $userId,
                'body' => $validated['message'],
                'type' => 'text',
            ]);

            $conversation->update(['last_message_at' => now()]);

            // Notify seller via NotificationService
            $this->notif->notifyMessage(
                $validated['seller_id'],
                $request->user(),
                $conversation->id,
                $validated['message']
            );
        }

        return response()->json([
            'conversation' => $conversation->load('buyer', 'seller', 'product', 'messages'),
            'message' => $message,
        ], 201);
    }

    public function show(Request $request, Conversation $conversation): JsonResponse
    {
        $userId = $request->user()->id;
        if ($conversation->buyer_id !== $userId && $conversation->seller_id !== $userId) abort(403);

        $conversation->messages()
            ->where('sender_id', '!=', $userId)
            ->where('is_read', false)
            ->update(['is_read' => true, 'read_at' => now()]);

        return response()->json([
            'conversation' => $conversation->load(['buyer', 'seller', 'product', 'messages.sender']),
        ]);
    }

    public function sendMessage(Request $request, Conversation $conversation): JsonResponse
    {
        $userId = $request->user()->id;
        if ($conversation->buyer_id !== $userId && $conversation->seller_id !== $userId) abort(403);

        $validated = $request->validate([
            'body' => 'required|string|max:2000',
            'type' => 'sometimes|in:text,image,offer,audio',
            'metadata' => 'sometimes|array',
        ]);

        $message = Message::create([
            'conversation_id' => $conversation->id,
            'sender_id' => $userId,
            'body' => $validated['body'],
            'type' => $validated['type'] ?? 'text',
            'metadata' => $validated['metadata'] ?? null,
        ]);

        $conversation->update(['last_message_at' => now()]);

        $recipientId = $conversation->buyer_id === $userId ? $conversation->seller_id : $conversation->buyer_id;
        $this->notif->notifyMessage($recipientId, $request->user(), $conversation->id, $validated['body']);

        return response()->json(['message' => $message->load('sender')]);
    }

    public function sendFile(Request $request, Conversation $conversation): JsonResponse
    {
        $userId = $request->user()->id;
        if ($conversation->buyer_id !== $userId && $conversation->seller_id !== $userId) abort(403);

        $request->validate([
            'file' => 'required|file|max:20480', // 20 MB max
        ]);

        $file = $request->file('file');
        $originalName = $file->getClientOriginalName();
        $extension = $file->getClientOriginalExtension();
        $mimeType = $file->getMimeType();
        $fileSize = $file->getSize();

        // Determine if it's an image
        $isImage = str_starts_with($mimeType, 'image/');
        $folder = $isImage ? 'messages/images' : 'messages/files';
        $type = $isImage ? 'image' : 'file';

        $path = $file->store($folder, 'public');
        $fileUrl = url('/storage/' . $path);

        $message = Message::create([
            'conversation_id' => $conversation->id,
            'sender_id' => $userId,
            'body' => $isImage ? '📷 Image' : '📎 ' . $originalName,
            'type' => $type,
            'metadata' => [
                'file_url' => $fileUrl,
                'file_name' => $originalName,
                'file_size' => $fileSize,
                'mime_type' => $mimeType,
                'extension' => $extension,
            ],
        ]);

        $conversation->update(['last_message_at' => now()]);

        $recipientId = $conversation->buyer_id === $userId ? $conversation->seller_id : $conversation->buyer_id;
        $this->notif->notifyMessage($recipientId, $request->user(), $conversation->id, $isImage ? '📷 Image' : '📎 ' . $originalName);

        return response()->json(['message' => $message->load('sender')]);
    }

    public function sendAudio(Request $request, Conversation $conversation): JsonResponse
    {
        $userId = $request->user()->id;
        if ($conversation->buyer_id !== $userId && $conversation->seller_id !== $userId) abort(403);

        $request->validate([
            'audio' => 'required|file|mimes:webm,ogg,mp3,wav,m4a,mp4|max:10240',
            'duration' => 'sometimes|numeric|min:0',
        ]);

        $file = $request->file('audio');
        $path = $file->store('messages/audio', 'public');
        $audioUrl = url('/storage/' . $path);
        $duration = $request->input('duration', 0);

        $message = Message::create([
            'conversation_id' => $conversation->id,
            'sender_id' => $userId,
            'body' => 'Message vocal',
            'type' => 'audio',
            'metadata' => [
                'audio_url' => $audioUrl,
                'duration' => round((float)$duration, 1),
                'mime_type' => $file->getMimeType(),
                'file_size' => $file->getSize(),
            ],
        ]);

        $conversation->update(['last_message_at' => now()]);

        $recipientId = $conversation->buyer_id === $userId ? $conversation->seller_id : $conversation->buyer_id;
        $this->notif->notifyMessage($recipientId, $request->user(), $conversation->id, '🎤 Message vocal');

        return response()->json(['message' => $message->load('sender')]);
    }

    public function destroy(Request $request, Conversation $conversation): JsonResponse
    {
        $userId = $request->user()->id;
        if ($conversation->buyer_id !== $userId && $conversation->seller_id !== $userId) abort(403);

        $conversation->messages()->delete();
        $conversation->delete();

        return response()->json(['message' => 'Conversation supprimée.']);
    }
}
