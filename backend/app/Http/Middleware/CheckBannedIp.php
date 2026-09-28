<?php

namespace App\Http\Middleware;

use App\Models\BannedIp;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class CheckBannedIp
{
    public function handle(Request $request, Closure $next): Response
    {
        if (BannedIp::where('ip_address', $request->ip())->exists()) {
            return response()->json([
                'message' => 'Acces refuse depuis cette adresse IP.',
            ], 403);
        }

        return $next($request);
    }
}
