<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Concerns\AdminHelpers;
use App\Http\Controllers\Controller;
use App\Jobs\BroadcastNotificationJob;
use App\Models\AdminActionLog;
use App\Models\FeedBanner;
use App\Models\SiteSetting;
use App\Models\User;
use App\Services\Admin\AdminLogger;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

/**
 * Réglages pilotables depuis l'admin : bannières du feed, message défilant,
 * boost Premium, interrupteurs de fonctionnalités, prix, mode maintenance,
 * paramètres de modération, mots interdits, modèles et envoi de notifications.
 */
class AdminSettingsController extends Controller
{
    use AdminHelpers;

    /**
     * key => [type, default, permission requise, groupe].
     * Groupe "system" : mot de passe de confirmation exigé en plus.
     */
    private function schema(): array
    {
        $q = config('quinch');

        return [
            // Feed
            'feed.ticker_enabled'  => ['bool', true, 'feed.manage', 'content'],
            'feed.ticker_label'    => ['string', 'QUINCH • INFO', 'feed.manage', 'content'],
            'feed.ticker_messages' => ['list', [], 'feed.manage', 'content'],
            'feed.premium_boost'   => ['int:0:200', (int) ($q['premium']['feed_boost'] ?? 30), 'feed.manage', 'content'],

            // Modération
            'moderation.strike_threshold'       => ['int:1:20', 3, 'feed.manage', 'content'],
            'moderation.strike_suspension_days' => ['int:1:365', 7, 'feed.manage', 'content'],
            'moderation.strike_expiry_days'     => ['int:0:3650', 180, 'feed.manage', 'content'],
            'moderation.auto_hide_reporters'    => ['int:2:50', 3, 'feed.manage', 'content'],
            'moderation.auto_hide_weight'       => ['float:0.5:50', 1.5, 'feed.manage', 'content'],
            'moderation.banned_words'           => ['list', [], 'feed.manage', 'content'],
            'moderation.screen_phone'           => ['bool', true, 'feed.manage', 'content'],
            'moderation.screen_links'           => ['bool', true, 'feed.manage', 'content'],

            // Modèles de notification
            'notifications.templates' => ['templates', [], 'notifications.broadcast', 'content'],

            // Système (super admin + mot de passe)
            'maintenance.enabled' => ['bool', false, 'settings.manage', 'system'],
            'maintenance.message' => ['string', 'QUINCH est en maintenance. Revenez dans quelques instants.', 'settings.manage', 'system'],
            'premium.price_monthly' => ['int:0:10000000', (int) ($q['premium']['prices']['monthly'] ?? 2000), 'settings.manage', 'system'],
            'premium.price_annual'  => ['int:0:10000000', (int) ($q['premium']['prices']['annual'] ?? 20000), 'settings.manage', 'system'],
            'premium.listing_fee_with_video' => ['int:0:100000', (int) ($q['premium']['listing_fee_with_video'] ?? 150), 'settings.manage', 'system'],
            'features.negotiation' => ['bool', (bool) ($q['features']['negotiation'] ?? false), 'settings.manage', 'system'],
            'features.follow' => ['bool', (bool) ($q['features']['follow'] ?? false), 'settings.manage', 'system'],
            'features.reviews' => ['bool', (bool) ($q['features']['reviews'] ?? false), 'settings.manage', 'system'],
            'features.badges' => ['bool', (bool) ($q['features']['badges'] ?? false), 'settings.manage', 'system'],
            'features.sharing' => ['bool', (bool) ($q['features']['sharing'] ?? false), 'settings.manage', 'system'],
            'features.chat_audio' => ['bool', (bool) ($q['features']['chat_audio'] ?? false), 'settings.manage', 'system'],
            'features.chat_file' => ['bool', (bool) ($q['features']['chat_file'] ?? false), 'settings.manage', 'system'],
            'features.favorites_collections' => ['bool', (bool) ($q['features']['favorites_collections'] ?? false), 'settings.manage', 'system'],
            'features.purchases' => ['bool', (bool) ($q['features']['purchases'] ?? false), 'settings.manage', 'system'],
        ];
    }

    public function index(Request $request): JsonResponse
    {
        $user = $request->user();
        $out = [];

        foreach ($this->schema() as $key => [$type, $default, $perm, $group]) {
            if (!$user->hasPermission($perm)) {
                continue;
            }
            $out[$key] = [
                'value' => SiteSetting::get($key, $default),
                'default' => $default,
                'type' => explode(':', $type)[0],
                'group' => $group,
            ];
        }

        return response()->json(['settings' => $out]);
    }

    /** Réglages de contenu / modération (permission par clé). */
    public function update(Request $request): JsonResponse
    {
        return $this->apply($request, 'content');
    }

    /** Réglages système (maintenance, prix, interrupteurs) : super_admin + mot de passe (middleware `sensitive`). */
    public function updateSystem(Request $request): JsonResponse
    {
        return $this->apply($request, 'system');
    }

    private function apply(Request $request, string $group): JsonResponse
    {
        $schema = $this->schema();
        $input = $request->input('settings');

        if (!is_array($input) || !$input) {
            return response()->json(['message' => 'Aucun réglage fourni.'], 422);
        }

        $clean = [];
        $errors = [];

        foreach ($input as $key => $raw) {
            if (!isset($schema[$key]) || $schema[$key][3] !== $group) {
                $errors[$key] = 'Réglage inconnu.';
                continue;
            }
            if (!$request->user()->hasPermission($schema[$key][2])) {
                $errors[$key] = 'Permission insuffisante.';
                continue;
            }

            [$ok, $value] = $this->cast($schema[$key][0], $raw);
            if (!$ok) {
                $errors[$key] = 'Valeur invalide.';
                continue;
            }
            $clean[$key] = $value;
        }

        if ($errors) {
            return response()->json(['message' => 'Certains réglages sont invalides.', 'errors' => $errors], 422);
        }

        foreach ($clean as $key => $value) {
            $old = SiteSetting::get($key, $schema[$key][1]);
            SiteSetting::put($key, $value, $request->user()->id);
            AdminLogger::log($request->user(), 'setting_changed', 'Setting', null, [
                'key' => $key, 'old' => $old, 'new' => $value,
            ], $group === 'system' ? 'critical' : 'info');
        }

        return response()->json(['message' => 'Réglages enregistrés.', 'saved' => array_keys($clean)]);
    }

    private function cast(string $type, mixed $raw): array
    {
        $parts = explode(':', $type);

        switch ($parts[0]) {
            case 'bool':
                $v = filter_var($raw, FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);

                return [$v !== null, $v];
            case 'string':
                return [is_string($raw) && mb_strlen($raw) <= 300, is_string($raw) ? trim($raw) : null];
            case 'int':
                if (!is_numeric($raw)) return [false, null];
                $v = (int) $raw;

                return [$v >= (int) $parts[1] && $v <= (int) $parts[2], $v];
            case 'float':
                if (!is_numeric($raw)) return [false, null];
                $v = (float) $raw;

                return [$v >= (float) $parts[1] && $v <= (float) $parts[2], $v];
            case 'list':
                if (!is_array($raw) || count($raw) > 500) return [false, null];
                $list = array_values(array_filter(array_map(fn ($i) => is_string($i) ? mb_substr(trim($i), 0, 300) : '', $raw), fn ($i) => $i !== ''));

                return [true, $list];
            case 'templates':
                if (!is_array($raw) || count($raw) > 50) return [false, null];
                $out = [];
                foreach ($raw as $t) {
                    if (!is_array($t) || empty($t['name']) || empty($t['title']) || empty($t['body'])) return [false, null];
                    $out[] = [
                        'name' => mb_substr((string) $t['name'], 0, 80),
                        'title' => mb_substr((string) $t['title'], 0, 200),
                        'body' => mb_substr((string) $t['body'], 0, 1000),
                    ];
                }

                return [true, $out];
        }

        return [false, null];
    }

    // ─── Bannières du feed ───────────────────────────────────────────────

    public function banners(): JsonResponse
    {
        return response()->json(['banners' => FeedBanner::orderBy('sort_order')->latest()->get()]);
    }

    public function storeBanner(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'title' => ['required', 'string', 'max:150'],
            'image' => ['required', 'image', 'mimes:jpg,jpeg,png,webp', 'max:4096'],
            'link_url' => ['nullable', 'url', 'max:500'],
            'is_active' => ['nullable', 'boolean'],
            'starts_at' => ['nullable', 'date'],
            'ends_at' => ['nullable', 'date', 'after_or_equal:starts_at'],
            'city' => ['nullable', 'string', 'max:100'],
            'sort_order' => ['nullable', 'integer', 'min:0', 'max:1000'],
        ]);

        $path = $request->file('image')->store('banners', 'public');
        unset($validated['image']);

        $banner = FeedBanner::create($validated + [
            'image_path' => $path,
            'created_by' => $request->user()->id,
            'is_active' => $validated['is_active'] ?? true,
        ]);

        AdminLogger::log($request->user(), 'banner_created', 'FeedBanner', $banner->id, ['title' => $banner->title]);

        return response()->json(['message' => 'Bannière créée.', 'banner' => $banner], 201);
    }

    public function updateBanner(Request $request, FeedBanner $banner): JsonResponse
    {
        $validated = $request->validate([
            'title' => ['sometimes', 'string', 'max:150'],
            'image' => ['sometimes', 'image', 'mimes:jpg,jpeg,png,webp', 'max:4096'],
            'link_url' => ['sometimes', 'nullable', 'url', 'max:500'],
            'is_active' => ['sometimes', 'boolean'],
            'starts_at' => ['sometimes', 'nullable', 'date'],
            'ends_at' => ['sometimes', 'nullable', 'date'],
            'city' => ['sometimes', 'nullable', 'string', 'max:100'],
            'sort_order' => ['sometimes', 'integer', 'min:0', 'max:1000'],
        ]);

        if ($request->hasFile('image')) {
            $old = $banner->getRawOriginal('image_path');
            $validated['image_path'] = $request->file('image')->store('banners', 'public');
            if ($old && !str_starts_with($old, 'http')) {
                Storage::disk('public')->delete($old);
            }
        }
        unset($validated['image']);

        $banner->update($validated);
        AdminLogger::log($request->user(), 'banner_updated', 'FeedBanner', $banner->id, array_keys($validated));

        return response()->json(['message' => 'Bannière mise à jour.', 'banner' => $banner->fresh()]);
    }

    public function destroyBanner(Request $request, FeedBanner $banner): JsonResponse
    {
        $path = $banner->getRawOriginal('image_path');
        AdminLogger::log($request->user(), 'banner_deleted', 'FeedBanner', $banner->id, ['title' => $banner->title], 'warning');
        $banner->delete();

        if ($path && !str_starts_with($path, 'http')) {
            Storage::disk('public')->delete($path);
        }

        return response()->json(['message' => 'Bannière supprimée.']);
    }

    /**
     * PUBLIC (sans authentification) : ce que le feed affiche. Si rien n'est
     * configuré, `banners` est vide et `ticker.messages` aussi : le front
     * retombe alors sur l'image et les messages d'origine.
     */
    public function publicFeedConfig(Request $request): JsonResponse
    {
        $city = trim((string) $request->query('city', ''));

        $banners = FeedBanner::live()
            ->where(fn ($q) => $q->whereNull('city')->orWhere('city', '')->when($city !== '', fn ($w) => $w->orWhere('city', $city)))
            ->orderBy('sort_order')
            ->get(['id', 'title', 'image_path', 'link_url', 'city'])
            ->map(fn ($b) => ['id' => $b->id, 'title' => $b->title, 'image_url' => $b->image_url, 'link_url' => $b->link_url]);

        return response()->json([
            'banners' => $banners,
            'ticker' => [
                'enabled' => (bool) SiteSetting::get('feed.ticker_enabled', true),
                'label' => (string) SiteSetting::get('feed.ticker_label', 'QUINCH • INFO'),
                'messages' => array_values((array) SiteSetting::get('feed.ticker_messages', [])),
            ],
            'maintenance' => (bool) SiteSetting::get('maintenance.enabled', false),
        ])->header('Cache-Control', 'public, max-age=60');
    }

    // ─── Notifications de masse ──────────────────────────────────────────

    /** Décompte des destinataires (sans envoi, sans mot de passe). */
    public function countAudience(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'audience' => ['required', 'in:all,premium,sellers,city'],
            'city' => ['required_if:audience,city', 'nullable', 'string', 'max:100'],
        ]);

        return response()->json(['recipients' => $this->audienceQuery($validated['audience'], $validated['city'] ?? null)->count()]);
    }

    public function broadcast(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'title' => ['required', 'string', 'max:200'],
            'body' => ['required', 'string', 'max:1000'],
            'audience' => ['required', 'in:all,premium,sellers,city'],
            'city' => ['required_if:audience,city', 'nullable', 'string', 'max:100'],
            'action_url' => ['nullable', 'string', 'max:300', 'regex:/^\//'],
        ]);

        $count = $this->audienceQuery($validated['audience'], $validated['city'] ?? null)->count();
        if ($count === 0) {
            return response()->json(['message' => 'Aucun destinataire pour cette audience.'], 422);
        }

        BroadcastNotificationJob::dispatch(
            $validated['title'], $validated['body'], $validated['audience'],
            $validated['city'] ?? null, $validated['action_url'] ?? null
        );

        AdminLogger::log($request->user(), 'broadcast_sent', 'Notification', null, [
            'title' => $validated['title'], 'audience' => $validated['audience'],
            'city' => $validated['city'] ?? null, 'recipients' => $count,
        ], 'warning');

        return response()->json(['message' => "Notification en cours d'envoi à {$count} utilisateur(s).", 'recipients' => $count]);
    }

    public function broadcastHistory(): JsonResponse
    {
        return response()->json(
            AdminActionLog::where('action', 'broadcast_sent')->with('admin:id,full_name')->latest()->limit(50)->get()
        );
    }

    public static function audienceQuery(string $audience, ?string $city)
    {
        $q = User::query()->where('account_status', 'active')->whereNull('anonymized_at')->where('phone_verified', true);

        return match ($audience) {
            'premium' => $q->where('is_premium', true)->where('premium_expires_at', '>', now()),
            'sellers' => $q->where('is_seller', true),
            'city' => $q->where('city', $city),
            default => $q,
        };
    }
}
