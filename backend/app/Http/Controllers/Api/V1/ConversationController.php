<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Conversation;
use App\Models\ConversationProductTag;
use App\Models\Message;
use App\Services\ConversationTaggingService;
use App\Services\NotificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Database\QueryException;
use App\Models\Product;
use Illuminate\Support\Facades\Storage;

class ConversationController extends Controller
{
    public function __construct(private NotificationService $notif) {}

    public function index(Request $request): JsonResponse
    {
        $userId = $request->user()->id;

        $conversations = Conversation::where('buyer_id', $userId)
            ->orWhere('seller_id', $userId)
            ->with(['buyer:id,full_name,avatar_url,username,last_seen_at', 'seller:id,full_name,avatar_url,username,last_seen_at', 'product:id,title,slug,price', 'lastMessage'])
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
    try {
        $conversation = Conversation::create([
            'buyer_id' => $userId,
            'seller_id' => $validated['seller_id'],
            'product_id' => $validated['product_id'] ?? null,
            'status' => 'active',
            'last_message_at' => now(),
        ]);
    } catch (QueryException $e) {
        if (($e->errorInfo[0] ?? null) === '23505') {
            $conversation = Conversation::where(function ($q) use ($userId, $validated) {
                    $q->where('buyer_id', $userId)->where('seller_id', $validated['seller_id']);
                })
                ->orWhere(function ($q) use ($userId, $validated) {
                    $q->where('buyer_id', $validated['seller_id'])->where('seller_id', $userId);
                })
                ->firstOrFail();
        } else {
            throw $e;
        }
    }
}

        $message = null;
if (!empty($validated['message'])) {
    $type = 'text';
    $metadata = null;

    if (!empty($validated['product_id'])) {
        $product = Product::find($validated['product_id']);
        if ($product) {
            // Cree/retrouve le tag silencieux (unique par produit, voir
            // ConversationProductTag), mais sans poster de message a part :
            // le message de contact ci-dessous PORTE le tag directement.
            app(ConversationTaggingService::class)->tagProduct($conversation, $product, $userId, null, postMessage: false);

            $type = 'product_tag';
            $metadata = [
                'product_id' => $product->id,
                'product_slug' => $product->slug,
                'product_title' => $product->title,
                'product_price' => $product->price,
                'product_type' => $product->type ?? 'product',
                'product_image' => $product->poster_full_url ?? ($product->images[0] ?? null),
            ];
        }
    }

    $message = Message::create([
        'conversation_id' => $conversation->id,
        'sender_id' => $userId,
        'body' => $validated['message'],
        'type' => $type,
        'metadata' => $metadata,
    ]);

    $conversation->update(['last_message_at' => now()]);

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

        $conversation->load(['buyer', 'seller', 'product', 'productTags.product', 'productTags.taggedBy']);
        $conversation->setRelation('messages', $conversation->messages()
            ->with('sender')
            ->orderByDesc('created_at')
            ->limit(50)
            ->get()
            ->sortBy('created_at')
            ->values());
        // index() calcule deja other_user ; show() ne le faisait pas, ce qui
        // laissait le nom/avatar/statut du contact vide des qu'on ouvrait une
        // conversation precise (visible uniquement dans la liste avant).
        $conversation->other_user = $conversation->buyer_id === $userId ? $conversation->seller : $conversation->buyer;

        return response()->json([
            'conversation' => $conversation,
        ]);
    }

        public function newMessages(Request $request, Conversation $conversation): JsonResponse
    {
        $userId = $request->user()->id;
        if ($conversation->buyer_id !== $userId && $conversation->seller_id !== $userId) abort(403);

        $after = $request->query('after');

        $query = $conversation->messages()->with('sender');
        if ($after) {
            $query->where('created_at', '>', $after);
        } else {
            $query->orderByDesc('created_at')->limit(50);
        }
        $messages = $query->orderBy('created_at')->get();

        $conversation->messages()
            ->where('sender_id', '!=', $userId)
            ->where('is_read', false)
            ->update(['is_read' => true, 'read_at' => now()]);

        $conversation->load(['buyer', 'seller']);
        $otherUser = $conversation->buyer_id === $userId ? $conversation->seller : $conversation->buyer;

        return response()->json([
            'messages' => $messages,
            'other_user' => $otherUser,
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

    public function deleteMessage(Request $request, Conversation $conversation, Message $message): JsonResponse
{
    $userId = $request->user()->id;
    if ($conversation->buyer_id !== $userId && $conversation->seller_id !== $userId) abort(403);
    if ($message->conversation_id !== $conversation->id) abort(404);
    if ($message->sender_id !== $userId) {
        return response()->json(['message' => 'Vous ne pouvez supprimer que vos propres messages.'], 403);
    }

    $message->delete();

    return response()->json(['message' => 'Message supprime.']);
}

public function bulkDestroy(Request $request): JsonResponse
{
    $userId = $request->user()->id;

    $validated = $request->validate([
        'conversation_ids' => ['required', 'array', 'min:1'],
        'conversation_ids.*' => ['uuid'],
    ]);

    $conversations = Conversation::whereIn('id', $validated['conversation_ids'])
        ->where(function ($q) use ($userId) {
            $q->where('buyer_id', $userId)->orWhere('seller_id', $userId);
        })
        ->get();

    foreach ($conversations as $conversation) {
        $conversation->messages()->delete();
        $conversation->delete();
    }

    return response()->json(['deleted' => $conversations->pluck('id')]);
}

public function sendFile(Request $request, Conversation $conversation): JsonResponse
{
    $userId = $request->user()->id;
    if ($conversation->buyer_id !== $userId && $conversation->seller_id !== $userId) abort(403);

    $request->validate([
        // Whitelist stricte : images, documents, audios/musiques et vidéos
        // usuels seulement — jamais d'exécutables/scripts. "Autres fichiers"
        // (mimes:*) volontairement retiré.
        'file' => [
            'required',
            'file',
            'max:20480', // 20 MB max
            'mimes:jpg,jpeg,png,webp,pdf,doc,docx,xls,xlsx,ppt,pptx,txt,csv,mp3,wav,ogg,m4a,aac,mp4,webm,mov,mkv',
        ],
    ]);

    $file = $request->file('file');
    $originalName = $file->getClientOriginalName();
    $extension = $file->getClientOriginalExtension();
    $mimeType = $file->getMimeType();
    $fileSize = $file->getSize();

    $isImage = str_starts_with($mimeType, 'image/');
    $isVideo = str_starts_with($mimeType, 'video/');
    $isAudio = str_starts_with($mimeType, 'audio/');

        // V1 : seules les images sont envoyables. Documents et vidéos restent
    // derrière chat_file, l'audio derrière chat_audio — la version suivante
    // les activera (mêmes flags déjà utilisés ailleurs dans l'app).
    if ($isAudio && !config('quinch.features.chat_audio')) {
        return response()->json(['message' => "L'envoi de fichiers audio sera bientôt disponible."], 403);
    }
    if (!$isImage && !$isAudio && !config('quinch.features.chat_file')) {
        return response()->json(['message' => "L'envoi de ce type de fichier sera bientôt disponible."], 403);
    }

    $folder = match (true) {
        $isImage => 'messages/images',
        $isVideo => 'messages/videos',
        $isAudio => 'messages/audio-files',
        default => 'messages/files',
    };
    $type = match (true) {
        $isImage => 'image',
        $isVideo => 'video',
        // Un audio envoyé via "Joindre" reste un fichier téléchargeable
        // classique (pas le lecteur à forme d'onde du vocal enregistré,
        // qui passe par sendAudio(), un flux distinct).
        default => 'file',
    };

    $path = $file->store($folder, 'public');
    $fileUrl = url('/storage/' . $path);

    $preview = match (true) {
        $isImage => '📷 Image',
        $isVideo => '🎬 Vidéo',
        $isAudio => '🎵 ' . $originalName,
        default => '📎 ' . $originalName,
    };

    $message = Message::create([
        'conversation_id' => $conversation->id,
        'sender_id' => $userId,
        'body' => $preview,
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
    $this->notif->notifyMessage($recipientId, $request->user(), $conversation->id, $preview);

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

        public function tagProduct(Request $request, Conversation $conversation): JsonResponse
    {
        $userId = $request->user()->id;
        if ($conversation->buyer_id !== $userId && $conversation->seller_id !== $userId) abort(403);

        $validated = $request->validate([
            'product_id' => ['required', 'uuid', 'exists:products,id'],
        ]);

        $product = Product::findOrFail($validated['product_id']);

        $tag = app(ConversationTaggingService::class)->tagProduct($conversation, $product, $userId);

        return response()->json(['tag' => $tag->load('product', 'taggedBy')], 201);
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
