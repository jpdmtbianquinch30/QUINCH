<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Concerns\AdminHelpers;
use App\Http\Controllers\Controller;
use App\Models\PremiumSubscription;
use App\Models\User;
use App\Services\Admin\AdminLogger;
use App\Services\NotificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AdminPremiumController extends Controller
{
    use AdminHelpers;

    public function __construct(private NotificationService $notif) {}

    public function index(Request $request): JsonResponse
    {
        $query = PremiumSubscription::with('user:id,full_name,username,email,phone_number,premium_expires_at,is_premium');

        if ($status = $request->query('status')) {
            $query->where('status', $status);
        }
        if ($request->query('expiring') === '1') {
            $query->where('status', 'active')->whereBetween('expires_at', [now(), now()->addDays(7)]);
        }

        return response()->json([
            'stats' => [
                'active' => User::where('is_premium', true)->where('premium_expires_at', '>', now())->count(),
                'expiring_7d' => User::where('is_premium', true)->whereBetween('premium_expires_at', [now(), now()->addDays(7)])->count(),
                'pending' => PremiumSubscription::pending()->count(),
            ],
            'subscriptions' => $query->latest()->paginate($this->perPage($request, 20, 100)),
        ]);
    }

    /** Octroi manuel (geste commercial, partenariat) : n'est pas du chiffre d'affaires (amount = 0). */
    public function grant(Request $request, User $user): JsonResponse
    {
        $validated = $request->validate([
            'days' => ['required', 'integer', 'min:1', 'max:730'],
            'reason' => $this->reasonRules(),
        ]);

        $sub = PremiumSubscription::create([
            'user_id' => $user->id,
            'plan' => 'monthly',
            'amount' => 0,
            'currency' => 'XOF',
            'status' => 'pending',
            'payment_method' => 'admin_grant',
        ]);
        $sub->setRelation('user', $user);
        $sub->activate();

        // activate() ajoute 1 mois : on cale la date sur la durée accordée
        // (en prolongeant un Premium encore actif plutôt que de le raccourcir).
        $previous = $user->getOriginal('premium_expires_at');
        $start = ($previous && \Illuminate\Support\Carbon::parse($previous)->isFuture()) ? \Illuminate\Support\Carbon::parse($previous) : now();
        $expires = $start->copy()->addDays((int) $validated['days']);
        $sub->update(['expires_at' => $expires]);
        $user->forceFill(['premium_expires_at' => $expires])->save();

        AdminLogger::log($request->user(), 'premium_granted', 'User', $user->id, [
            'days' => (int) $validated['days'], 'reason' => $validated['reason'],
        ]);

        $this->notif->notifyAdmin($user->id, 'Premium offert', "Vous bénéficiez de QUINCH Premium pendant {$validated['days']} jours.", null, ['kind' => 'premium_granted']);

        return response()->json(['message' => 'Premium accordé.', 'user' => $user->fresh()]);
    }

    public function revoke(Request $request, User $user): JsonResponse
    {
        $validated = $request->validate(['reason' => $this->reasonRules()]);

        $user->forceFill(['is_premium' => false, 'premium_plan' => null, 'premium_expires_at' => now()])->save();
        PremiumSubscription::where('user_id', $user->id)->where('status', 'active')->update(['status' => 'cancelled', 'expires_at' => now()]);

        AdminLogger::log($request->user(), 'premium_revoked', 'User', $user->id, ['reason' => $validated['reason']], 'warning');
        $this->notif->notifyAdmin($user->id, 'Premium retiré', 'Votre abonnement Premium a pris fin. Motif : ' . $validated['reason'], null, ['kind' => 'premium_revoked']);

        return response()->json(['message' => 'Premium retiré.', 'user' => $user->fresh()]);
    }
}
