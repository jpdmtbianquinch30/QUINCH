<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\PremiumSubscription;
use App\Services\PaymentGateway\PaymentGatewayFactory;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\Rule;
use App\Support\VerifiesWaveWebhook;

class PremiumController extends Controller
{
    use VerifiesWaveWebhook;
    public function plans(): JsonResponse
    {
        return response()->json([
            'plans' => [
                ['id' => 'monthly', 'label' => 'Mensuel', 'price' => config('quinch.premium.prices.monthly'), 'currency' => 'XOF'],
                ['id' => 'annual', 'label' => 'Annuel', 'price' => config('quinch.premium.prices.annual'), 'currency' => 'XOF'],
            ],
        ]);
    }

    public function status(Request $request): JsonResponse
    {
        $user = $request->user();

        return response()->json([
            'is_premium' => $user->isPremiumActive(),
            'plan' => $user->premium_plan,
            'expires_at' => $user->premium_expires_at,
            'pending_subscription' => $user->premiumSubscriptions()
                ->where('status', 'pending')
                ->latest()
                ->first(),
        ]);
    }

    public function subscribe(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'plan' => ['required', Rule::in(['monthly', 'annual'])],
            'payment_method' => ['required', Rule::in(config('quinch.enabled_payment_methods', ['wave']))],
        ]);

        $user = $request->user();
        $price = config("quinch.premium.prices.{$validated['plan']}");

        $subscription = PremiumSubscription::create([
            'user_id' => $user->id,
            'plan' => $validated['plan'],
            'amount' => $price,
            'currency' => 'XOF',
            'status' => 'pending',
            'payment_method' => $validated['payment_method'],
        ]);

        $gateway = PaymentGatewayFactory::create($validated['payment_method']);
        $frontendUrl = rtrim(config('quinch.frontend_url'), '/');

        $result = $gateway->initiatePayment([
            'amount' => $price,
            'transaction_id' => 'premium_' . $subscription->id,
            'success_url' => "{$frontendUrl}/premium/success",
            'error_url' => "{$frontendUrl}/premium/error",
            'notif_url' => url('/api/v1/webhooks/wave-premium'),
        ]);

        if (!($result['success'] ?? false)) {
            $subscription->update(['status' => 'cancelled']);
            return response()->json([
                'message' => $result['message'] ?? "L'abonnement n'a pas pu être initié.",
            ], 502);
        }

        $subscription->update(['payment_gateway_id' => $result['gateway_reference'] ?? null]);

        return response()->json([
            'message' => 'Redirection vers le paiement.',
            'subscription' => $subscription,
            'payment_url' => $result['payment_url'],
        ], 201);
    }

    public function webhookWave(Request $request): JsonResponse
    {
        $secret = config('services.wave.webhook_secret');
        $header = $request->header('Wave-Signature');

        if (!$secret || !$header || !$this->verifyWaveSignature($header, $request->getContent(), $secret)) {
            Log::warning('Webhook Wave Premium: signature invalide', ['ip' => $request->ip()]);
            return response()->json(['error' => 'Signature invalide'], 401);
        }

        $payload = $request->json()->all();
        $data = $payload['data'] ?? [];
        $clientReference = $data['client_reference'] ?? null;

        // Le client_reference est préfixé "premium_" à l'initiation — on ne
        // traite ici que les paiements qui concernent réellement un abonnement,
        // pas un achat produit classique (même passerelle Wave pour les deux).
        if (!$clientReference || !str_starts_with($clientReference, 'premium_')) {
            return response()->json(['status' => 'ignored']);
        }

        $subscriptionId = substr($clientReference, strlen('premium_'));

        if (($payload['type'] ?? null) === 'checkout.session.completed' && ($data['payment_status'] ?? null) === 'succeeded') {
            $subscription = PremiumSubscription::find($subscriptionId);
            if ($subscription && $subscription->status === 'pending') {
                $subscription->update(['payment_gateway_id' => $data['id'] ?? $subscription->payment_gateway_id]);
                $subscription->activate();
            }
        }

        if (($payload['type'] ?? null) === 'checkout.session.payment_failed') {
            PremiumSubscription::where('id', $subscriptionId)->where('status', 'pending')->update(['status' => 'cancelled']);
        }

        return response()->json(['status' => 'received']);
    }
}