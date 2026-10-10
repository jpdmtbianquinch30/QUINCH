<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;

/**
 * Réglages publics dont le frontend a besoin pour afficher les bons prix
 * (jamais de secret ici). Évite de coder « 150 F » en dur dans Angular.
 */
class PublicConfigController extends Controller
{
    public function show(): JsonResponse
    {
        return response()->json([
            'beta' => (bool) config('quinch.beta', false),
            'listing_fee_with_video' => config('quinch.beta') ? 0 : (int) config('quinch.premium.listing_fee_with_video', 150),
            'premium_offer_slots' => (int) config('quinch.premium.offer.slots', 100),
            'premium_payments' => (bool) config('quinch.premium.payments_enabled', true),
        ]);
    }
}
