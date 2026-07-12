<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\ProductReport;
use App\Models\ProductVideo;
use App\Models\SupportTicket;
use App\Models\UserReport;
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

    /**
     * Liste des signalements de produits, en attente par défaut.
     * Remplace l'absence totale de route admin pour consulter ces
     * signalements (ils étaient soit jamais enregistrés à cause d'un bug,
     * soit enregistrés mais invisibles pour l'admin).
     */
    public function productReports(Request $request): JsonResponse
    {
        $status = $request->get('status', 'pending');
        $query = ProductReport::with(['reporter:id,full_name,username', 'product:id,title,slug,user_id']);

        if ($status !== 'all') {
            $query->where('status', $status);
        }

        return response()->json($query->latest()->paginate(20));
    }

    public function resolveProductReport(Request $request, ProductReport $report): JsonResponse
    {
        $validated = $request->validate([
            'status' => ['required', 'in:reviewed,resolved,dismissed'],
            'admin_notes' => ['nullable', 'string', 'max:1000'],
        ]);

        $report->update([
            'status' => $validated['status'],
            'admin_notes' => $validated['admin_notes'] ?? $report->admin_notes,
            'reviewed_by' => $request->user()->id,
        ]);

        return response()->json(['message' => 'Signalement traité.', 'report' => $report->fresh()]);
    }

    /**
     * Liste des signalements d'utilisateurs, en attente par défaut.
     */
    public function userReports(Request $request): JsonResponse
    {
        $status = $request->get('status', 'pending');
        $query = UserReport::with(['reporter:id,full_name,username', 'reportedUser:id,full_name,username,account_status']);

        if ($status !== 'all') {
            $query->where('status', $status);
        }

        return response()->json($query->latest()->paginate(20));
    }

    public function resolveUserReport(Request $request, UserReport $report): JsonResponse
    {
        $validated = $request->validate([
            'status' => ['required', 'in:reviewed,resolved,dismissed'],
            'admin_notes' => ['nullable', 'string', 'max:1000'],
        ]);

        $report->update([
            'status' => $validated['status'],
            'admin_notes' => $validated['admin_notes'] ?? $report->admin_notes,
            'reviewed_by' => $request->user()->id,
        ]);

        return response()->json(['message' => 'Signalement traité.', 'report' => $report->fresh()]);
    }

    /**
     * Tickets de support (bug/suggestion/sécurité/autre) envoyés par les
     * utilisateurs depuis les Réglages.
     */
    public function supportTickets(Request $request): JsonResponse
    {
        $status = $request->get('status', 'pending');
        $query = SupportTicket::with('user:id,full_name,username,phone_number');

        if ($status !== 'all') {
            $query->where('status', $status);
        }

        return response()->json($query->latest()->paginate(20));
    }

    public function resolveSupportTicket(Request $request, SupportTicket $ticket): JsonResponse
    {
        $validated = $request->validate([
            'status' => ['required', 'in:reviewed,resolved'],
            'admin_notes' => ['nullable', 'string', 'max:1000'],
        ]);

        $ticket->update([
            'status' => $validated['status'],
            'admin_notes' => $validated['admin_notes'] ?? $ticket->admin_notes,
            'reviewed_by' => $request->user()->id,
        ]);

        return response()->json(['message' => 'Ticket traité.', 'ticket' => $ticket->fresh()]);
    }
}
