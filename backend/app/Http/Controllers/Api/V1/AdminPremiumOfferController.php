<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Concerns\AdminHelpers;
use App\Http\Controllers\Controller;
use App\Models\PremiumApplication;
use App\Models\PremiumSubscription;
use App\Services\Admin\AdminLogger;
use App\Services\NotificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/** Côté admin : examen des candidatures « Premium offert » (plafond = quinch.premium.offer.slots). */
class AdminPremiumOfferController extends Controller
{
    use AdminHelpers;

    public function __construct(private NotificationService $notif) {}

    public function index(Request $request): JsonResponse
    {
        $query = PremiumApplication::with('user:id,full_name,username,email,is_premium,premium_expires_at');
        if ($status = $request->query('status')) {
            $query->where('status', $status);
        }

        return response()->json([
            'slots_total' => (int) config('quinch.premium.offer.slots', 100),
            'slots_left' => PremiumApplication::slotsLeft(),
            'days' => (int) config('quinch.premium.offer.days', 90),
            'pending' => PremiumApplication::where('status', 'pending')->count(),
            'applications' => $query->orderBy('created_at')->paginate($this->perPage($request, 20, 100)),
        ]);
    }

    public function grant(Request $request, PremiumApplication $application): JsonResponse
    {
        $days = (int) config('quinch.premium.offer.days', 90);

        $result = DB::transaction(function () use ($application, $request, $days) {
            // Verrou : deux admins ne peuvent pas dépasser le plafond en même temps.
            $app = PremiumApplication::whereKey($application->id)->lockForUpdate()->first();
            if ($app->status === 'granted') {
                return 'already';
            }
            if (PremiumApplication::slotsLeft() <= 0) {
                return 'full';
            }

            $user = $app->user;
            $sub = PremiumSubscription::create([
                'user_id' => $user->id, 'plan' => 'monthly', 'amount' => 0, 'currency' => 'XOF',
                'status' => 'pending', 'payment_method' => 'admin_grant',
            ]);
            $sub->setRelation('user', $user);
            $sub->activate();

            $previous = $user->getOriginal('premium_expires_at');
            $start = ($previous && \Illuminate\Support\Carbon::parse($previous)->isFuture())
                ? \Illuminate\Support\Carbon::parse($previous) : now();
            $expires = $start->copy()->addDays($days);
            $sub->update(['expires_at' => $expires]);
            $user->forceFill(['premium_expires_at' => $expires])->save();

            $app->forceFill([
                'status' => 'granted', 'decided_by' => $request->user()->id, 'decided_at' => now(),
            ])->save();

            return $user;
        });

        if ($result === 'already') {
            return response()->json(['message' => 'Déjà accordé.']);
        }
        if ($result === 'full') {
            return response()->json(['message' => 'Toutes les places de l\'offre sont attribuées.'], 422);
        }

        AdminLogger::log($request->user(), 'premium_offer_granted', 'User', $result->id, ['days' => $days]);
        $this->notif->notifyAdmin($result->id, 'Premium offert 🎉',
            "Votre candidature est acceptée : vous bénéficiez de QUINCH Premium pendant {$days} jours.", null, ['kind' => 'premium_granted']);

        return response()->json(['message' => 'Premium offert.', 'slots_left' => PremiumApplication::slotsLeft()]);
    }

    public function reject(Request $request, PremiumApplication $application): JsonResponse
    {
        if ($application->status === 'granted') {
            return response()->json(['message' => 'Déjà accordé : utilisez « Retirer Premium » sur la fiche utilisateur.'], 422);
        }

        $application->forceFill([
            'status' => 'rejected', 'decided_by' => $request->user()->id, 'decided_at' => now(),
        ])->save();
        AdminLogger::log($request->user(), 'premium_offer_rejected', 'User', $application->user_id, []);

        return response()->json(['message' => 'Candidature refusée.']);
    }
}
