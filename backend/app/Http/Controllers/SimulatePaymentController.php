<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;

class SimulatePaymentController extends Controller
{
    public function show(Request $request)
    {
        abort_if(app()->environment('production'), 404);

        return view('dev.simulate-payment', [
            'reference' => $request->query('reference'),
            'amount' => $request->query('amount'),
            'successUrl' => $request->query('success_url'),
            'errorUrl' => $request->query('error_url'),
        ]);
    }

    public function confirm(Request $request)
    {
        abort_if(app()->environment('production'), 404);

        $validated = $request->validate([
            'reference' => ['required', 'string'],
            'outcome' => ['required', 'in:success,error'],
            'success_url' => ['required', 'url'],
            'error_url' => ['required', 'url'],
        ]);

        $reference = $validated['reference'];
        $secret = config('services.wave.webhook_secret');

        $body = json_encode([
            'type' => $validated['outcome'] === 'success' ? 'checkout.session.completed' : 'checkout.session.payment_failed',
            'data' => [
                'id' => 'sim_' . uniqid(),
                'client_reference' => $reference,
                'payment_status' => $validated['outcome'] === 'success' ? 'succeeded' : 'failed',
            ],
        ]);

        $timestamp = time();
        $signature = hash_hmac('sha256', $timestamp . $body, $secret);

        // On rejoue le webhook EN INTERNE (aucun appel réseau réel, aucun
        // risque de blocage), pour repasser par exactement la même logique
        // de vérification de signature et de traitement que le vrai Wave —
        // pas de duplication de la logique métier "marquer comme payé".
        $fakeRequest = Request::create(
            $this->resolveWebhookPath($reference),
            'POST',
            [],
            [],
            [],
            [
                'HTTP_WAVE-SIGNATURE' => "t={$timestamp},v1={$signature}",
                'CONTENT_TYPE' => 'application/json',
            ],
            $body
        );

        app()->handle($fakeRequest);

        $redirect = $validated['outcome'] === 'success' ? $validated['success_url'] : $validated['error_url'];

        return redirect()->away($redirect);
    }

    private function resolveWebhookPath(string $reference): string
    {
        return match (true) {
            str_starts_with($reference, 'listing_') => '/api/v1/webhooks/wave-listing',
            str_starts_with($reference, 'premium_') => '/api/v1/webhooks/wave-premium',
            default => '/api/v1/webhooks/wave',
        };
    }
}
