<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Support\VerifiesWaveWebhook;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

/**
 * Point d'entrée UNIQUE des webhooks Wave : POST /api/v1/webhooks/wave.
 *
 * Wave enregistre les webhooks dans le portail Business, au niveau du compte
 * (une URL + un secret par webhook) : tous les événements d'un compte arrivent
 * donc sur la même URL, quel que soit le produit payé. On vérifie la signature
 * une fois, puis on aiguille selon le préfixe du client_reference :
 *   premium_<uuid>  -> abonnement Premium
 *   listing_<uuid>  -> frais de publication vidéo
 *   <uuid>          -> commande (transaction)
 * Les anciennes URL /webhooks/wave-premium et /webhooks/wave-listing restent
 * actives pour ne rien casser, mais une seule URL suffit désormais.
 */
class WaveWebhookController extends Controller
{
    use VerifiesWaveWebhook;

    public function handle(Request $request): JsonResponse
    {
        $secret = $this->waveWebhookSecret();
        $header = $request->header('Wave-Signature');

        if (!$secret || !$header || !$this->verifyWaveSignature($header, $request->getContent(), $secret)) {
            Log::warning('Webhook Wave: signature invalide', ['ip' => $request->ip()]);

            return response()->json(['error' => 'Signature invalide'], 401);
        }

        $reference = $request->json('data.client_reference');

        if (!is_string($reference) || $reference === '') {
            return response()->json(['status' => 'ignored']);
        }

        if (str_starts_with($reference, 'premium_')) {
            return app(PremiumController::class)->webhookWave($request);
        }

        if (str_starts_with($reference, 'listing_')) {
            return app(ProductController::class)->webhookWaveListingFee($request);
        }

        // Commande : la référence est l'identifiant (uuid) de la transaction.
        if (Str::isUuid($reference)) {
            return app(TransactionController::class)->webhookWave($request);
        }

        return response()->json(['status' => 'ignored']);
    }
}
