<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Concerns\AdminHelpers;
use App\Http\Controllers\Controller;
use App\Models\BadgeDefinition;
use App\Models\UserBadge;
use App\Services\Admin\AdminLogger;
use App\Services\BadgeService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/**
 * Gestion des badges par l'admin : création, configuration (icône, couleur,
 * zones d'affichage), règle automatique (« brancher » le badge sur Premium,
 * KYC, ventes…), activation, suppression, synchronisation.
 */
class AdminBadgeController extends Controller
{
    use AdminHelpers;

    public function __construct(private BadgeService $badges) {}

    public function index(): JsonResponse
    {
        $counts = UserBadge::query()
            ->selectRaw("badge_type, COUNT(*) AS total, SUM(CASE WHEN source = 'auto' THEN 1 ELSE 0 END) AS auto_count")
            ->groupBy('badge_type')->get()->keyBy('badge_type');

        $items = BadgeDefinition::orderBy('sort_order')->orderBy('name')->get()->map(function (BadgeDefinition $d) use ($counts) {
            $c = $counts->get($d->key);

            return $d->toArray() + [
                'holders_count' => (int) ($c->total ?? 0),
                'auto_holders_count' => (int) ($c->auto_count ?? 0),
            ];
        });

        return response()->json([
            'badges' => $items,
            'zones' => collect(BadgeDefinition::ZONES)->map(fn ($label, $key) => ['key' => $key, 'label' => $label])->values(),
            'auto_rules' => collect(BadgeDefinition::AUTO_RULES)->map(fn ($label, $key) => [
                'key' => $key, 'label' => $label, 'needs_threshold' => in_array($key, BadgeDefinition::RULES_WITH_THRESHOLD, true),
            ])->values(),
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $this->validated($request);
        $data['key'] = $request->validate([
            'key' => ['required', 'string', 'regex:/^[a-z][a-z0-9_]{1,39}$/', 'unique:badge_definitions,key'],
        ], ['key.regex' => 'Identifiant : minuscules, chiffres et _ (2 à 40 caractères, commence par une lettre).'])['key'];
        $data['created_by'] = $request->user()->id;
        $data['is_system'] = false;

        $badge = BadgeDefinition::create($data);
        $this->badges->sync();

        AdminLogger::log($request->user(), 'badge_created', 'BadgeDefinition', $badge->id, ['key' => $badge->key]);

        return response()->json(['message' => 'Badge créé.', 'badge' => $badge->fresh()], 201);
    }

    public function update(Request $request, BadgeDefinition $badge): JsonResponse
    {
        $data = $this->validated($request);
        $ruleChanged = $badge->auto_rule !== $data['auto_rule'] || $badge->auto_threshold !== $data['auto_threshold'];

        $badge->update($data);

        // Règle modifiée / retirée : les anciennes attributions automatiques ne
        // sont plus justifiées ; on les efface puis on recalcule avec la nouvelle règle.
        if ($ruleChanged) {
            $this->badges->purgeAuto($badge->key);
        }
        $this->badges->sync();

        AdminLogger::log($request->user(), 'badge_updated', 'BadgeDefinition', $badge->id, ['key' => $badge->key]);

        return response()->json(['message' => 'Badge mis à jour.', 'badge' => $badge->fresh()]);
    }

    public function destroy(Request $request, BadgeDefinition $badge): JsonResponse
    {
        if ($badge->is_system) {
            return response()->json([
                'message' => "Les badges d'origine ne se suppriment pas : désactivez-le pour le masquer partout.",
                'error' => 'system_badge',
            ], 422);
        }

        UserBadge::where('badge_type', $badge->key)->delete();
        $badge->delete();

        AdminLogger::log($request->user(), 'badge_deleted', 'BadgeDefinition', $badge->id, ['key' => $badge->key], 'warning');

        return response()->json(['message' => 'Badge supprimé.']);
    }

    /** Recalcule immédiatement tous les badges automatiques. */
    public function sync(Request $request): JsonResponse
    {
        $report = $this->badges->sync();
        AdminLogger::log($request->user(), 'badges_synced', 'BadgeDefinition', null, $report);

        return response()->json(['message' => 'Badges automatiques recalculés.', 'report' => $report]);
    }

    /** Détenteurs d'un badge (pagination). */
    public function holders(Request $request, BadgeDefinition $badge): JsonResponse
    {
        $page = UserBadge::where('badge_type', $badge->key)
            ->with('user:id,full_name,username,avatar_url')
            ->latest()
            ->paginate($this->perPage($request, 20, 100));

        return response()->json($page);
    }

    private function validated(Request $request): array
    {
        $v = $request->validate([
            'name' => ['required', 'string', 'min:2', 'max:60'],
            'description' => ['nullable', 'string', 'max:300'],
            'how_to_get' => ['nullable', 'string', 'max:400'],
            'icon' => ['required', 'string', 'regex:/^[a-z][a-z0-9_]{1,59}$/'],
            'color' => ['required', 'string', 'regex:/^#[0-9a-fA-F]{6}$/'],
            'auto_rule' => ['nullable', Rule::in(array_keys(BadgeDefinition::AUTO_RULES))],
            'auto_threshold' => ['nullable', 'integer', 'min:1', 'max:100000'],
            'zones' => ['present', 'array'],
            'zones.*' => [Rule::in(array_keys(BadgeDefinition::ZONES))],
            'is_active' => ['boolean'],
            'sellers_can_award' => ['boolean'],
            'sort_order' => ['nullable', 'integer', 'min:0', 'max:10000'],
        ], ['icon.regex' => "Nom d'icône Material Icons invalide (ex. workspace_premium)."]);

        if ($v['auto_rule'] ?? null) {
            if (in_array($v['auto_rule'], BadgeDefinition::RULES_WITH_THRESHOLD, true) && empty($v['auto_threshold'])) {
                abort(response()->json(['message' => 'Cette règle exige un seuil.', 'errors' => ['auto_threshold' => ['Seuil requis.']]], 422));
            }
            if ($v['auto_rule'] === 'trust_score' && $v['auto_threshold'] > 100) {
                abort(response()->json(['message' => 'Le score de confiance se règle entre 1 et 100 %.', 'errors' => ['auto_threshold' => ['Max 100.']]], 422));
            }
            if (!in_array($v['auto_rule'], BadgeDefinition::RULES_WITH_THRESHOLD, true)) {
                $v['auto_threshold'] = null;
            }
        } else {
            $v['auto_rule'] = null;
            $v['auto_threshold'] = null;
        }

        $v['zones'] = array_values(array_unique($v['zones']));
        $v['is_active'] = $v['is_active'] ?? true;
        $v['sellers_can_award'] = $v['sellers_can_award'] ?? false;
        $v['sort_order'] = $v['sort_order'] ?? 0;

        return $v;
    }
}
