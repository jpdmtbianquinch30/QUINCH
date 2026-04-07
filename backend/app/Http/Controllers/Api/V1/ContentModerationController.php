<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\ProductVideo;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ContentModerationController extends Controller
{
    public function pending(): JsonResponse
    {
        $videos = ProductVideo::with(['user:id,full_name,username,avatar_url,trust_score', 'product:id,title,video_id'])
            ->pending()
            ->latest()
            ->paginate(20);

        return response()->json($videos);
    }

    public function moderate(Request $request, ProductVideo $video): JsonResponse
    {
        $validated = $request->validate([
            'status' => ['required', 'in:approved,rejected,flagged'],
            'reason' => ['required_if:status,rejected,flagged', 'string', 'max:500'],
        ]);

        $video->update([
            'moderation_status' => $validated['status'],
        ]);

        // If approved, boost engagement score
        if ($validated['status'] === 'approved') {
            $video->update(['engagement_score' => $video->engagement_score + 1.0]);
        }

        return response()->json([
            'message' => 'Vidéo modérée avec succès.',
            'video' => $video->fresh(),
        ]);
    }

    public function bulkAction(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'video_ids' => ['required', 'array'],
            'video_ids.*' => ['uuid', 'exists:product_videos,id'],
            'action' => ['required', 'in:approved,rejected'],
        ]);

        ProductVideo::whereIn('id', $validated['video_ids'])
            ->update(['moderation_status' => $validated['action']]);

        return response()->json([
            'message' => count($validated['video_ids']) . ' vidéos modérées.',
        ]);
    }
}
