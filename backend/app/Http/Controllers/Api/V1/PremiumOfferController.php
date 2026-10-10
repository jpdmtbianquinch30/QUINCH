<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\PremiumApplication;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/** Côté utilisateur : offre « Premium offert aux 100 premiers » pendant la bêta. */
class PremiumOfferController extends Controller
{
    public function show(Request $request): JsonResponse
    {
        $mine = PremiumApplication::where('user_id', $request->user()->id)->value('status');

        return response()->json([
            'slots_total' => (int) config('quinch.premium.offer.slots', 100),
            'slots_left' => PremiumApplication::slotsLeft(),
            'days' => (int) config('quinch.premium.offer.days', 90),
            'my_status' => $mine, // null | pending | granted | rejected
        ]);
    }

    public function apply(Request $request): JsonResponse
    {
        $user = $request->user();

        if ($user->isPremiumActive()) {
            return response()->json(['message' => 'Vous êtes déjà Premium.'], 422);
        }

        $existing = PremiumApplication::where('user_id', $user->id)->first();
        if ($existing) {
            return response()->json([
                'message' => 'Votre candidature est déjà enregistrée.',
                'my_status' => $existing->status,
            ]);
        }

        if (PremiumApplication::slotsLeft() <= 0) {
            return response()->json(['message' => "Les places de l'offre sont toutes attribuées."], 422);
        }

        PremiumApplication::create(['user_id' => $user->id]);

        return response()->json([
            'message' => 'Candidature envoyée. Nous vous préviendrons dès qu\'elle est examinée.',
            'my_status' => 'pending',
        ], 201);
    }
}
