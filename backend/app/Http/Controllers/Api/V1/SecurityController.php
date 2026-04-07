<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use App\Models\FraudDetection;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SecurityController extends Controller
{
    public function alerts(): JsonResponse
    {
        $alerts = FraudDetection::with(['user:id,full_name,phone_number,trust_score'])
            ->pendingReview()
            ->orderByDesc('confidence_score')
            ->paginate(20);

        return response()->json($alerts);
    }

    public function logs(Request $request): JsonResponse
    {
        $query = AuditLog::with('user:id,full_name');

        if ($request->has('severity')) {
            $query->where('severity', $request->severity);
        }

        if ($request->has('action_type')) {
            $query->where('action_type', $request->action_type);
        }

        $logs = $query->latest('created_at')->paginate(50);

        return response()->json($logs);
    }

    public function banIp(Request $request): JsonResponse
    {
        $request->validate([
            'ip_address' => ['required', 'ip'],
            'reason' => ['required', 'string', 'max:500'],
        ]);

        AuditLog::create([
            'user_id' => $request->user()->id,
            'action_type' => 'ip_banned',
            'entity_type' => 'Security',
            'ip_address' => $request->ip_address,
            'new_values' => ['reason' => $request->reason, 'banned_ip' => $request->ip_address],
            'severity' => 'critical',
        ]);

        return response()->json([
            'message' => "IP {$request->ip_address} bannie.",
        ]);
    }
}
