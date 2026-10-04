<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\ModerationAppeal;
use App\Models\Product;
use App\Models\ProductVideo;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/** Côté VENDEUR : contester le retrait d'une vidéo ou d'une annonce. */
class ModerationAppealController extends Controller
{
    public function mine(Request $request): JsonResponse
    {
        return response()->json(
            ModerationAppeal::where('user_id', $request->user()->id)->latest()->limit(50)->get()
        );
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'target_type' => ['required', 'in:video,product'],
            'target_id' => ['required', 'uuid'],
            'message' => ['required', 'string', 'min:10', 'max:2000'],
        ]);

        $user = $request->user();

        // On ne peut contester que SON contenu, et seulement s'il a réellement été retiré.
        if ($validated['target_type'] === 'video') {
            $target = ProductVideo::where('id', $validated['target_id'])->where('user_id', $user->id)
                ->whereIn('moderation_status', ['rejected', 'flagged'])->first();
        } else {
            $target = Product::withTrashed()->where('id', $validated['target_id'])->where('user_id', $user->id)
                ->where(fn ($q) => $q->where('status', 'disabled')->orWhereNotNull('deleted_at'))->first();
        }

        if (!$target) {
            return response()->json(['message' => "Ce contenu n'a pas fait l'objet d'un retrait que vous pouvez contester."], 422);
        }

        $exists = ModerationAppeal::where('user_id', $user->id)
            ->where('target_type', $validated['target_type'])->where('target_id', $validated['target_id'])
            ->where('status', 'pending')->exists();
        if ($exists) {
            return response()->json(['message' => 'Une contestation est déjà en cours pour ce contenu.'], 409);
        }

        $appeal = ModerationAppeal::create($validated + ['user_id' => $user->id]);

        return response()->json(['message' => 'Contestation envoyée. Notre équipe va la réexaminer.', 'appeal' => $appeal], 201);
    }
}
