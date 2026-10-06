<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Concerns\AdminHelpers;
use App\Http\Controllers\Controller;
use App\Models\AdminActionLog;
use App\Models\Product;
use App\Models\ProductReport;
use App\Models\ProductVideo;
use App\Services\Admin\AdminLogger;
use App\Services\Admin\ModerationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

/**
 * Module Produits de l'admin (n'existait pas du tout) : liste de TOUS les
 * produits (tous statuts, y compris supprimés), fiche complète, actions
 * unitaires et en masse, gestion des médias (retirer / remplacer une image).
 */
class AdminProductController extends Controller
{
    use AdminHelpers;

    public function __construct(private ModerationService $moderation) {}

    public function index(Request $request): JsonResponse
    {
        $query = Product::query()
            ->with([
                'user:id,full_name,username,avatar_url,trust_score,account_status',
                'category:id,name',
                'video:id,moderation_status,thumbnail_path,video_path,duration_seconds',
            ])
            ->withCount(['reports as pending_reports_count' => fn ($q) => $q->where('status', 'pending')]);

        match ($request->query('trashed')) {
            'only' => $query->onlyTrashed(),
            'with' => $query->withTrashed(),
            default => null,
        };

        if ($search = trim((string) $request->query('search', ''))) {
            $this->ilike($query, ['title', 'description', 'slug'], $search, ['id']);
        }

        if ($status = $request->query('status')) {
            $query->where('status', $status);
        }

        if ($category = $request->query('category_id')) {
            $query->where('category_id', $category);
        }

        if ($seller = $request->query('user_id')) {
            $query->where('user_id', $seller);
        }

        if ($request->query('reported') === '1') {
            $query->whereHas('reports', fn ($q) => $q->where('status', 'pending'));
        }

        if ($request->query('flagged') === '1') {
            $query->whereNotNull('screening_flags');
        }

        if ($request->query('has_video') === '1') {
            $query->whereNotNull('video_id');
        } elseif ($request->query('has_video') === '0') {
            $query->whereNull('video_id');
        }

        if ($request->query('pinned') === '1') {
            $query->where('is_pinned', true);
        }

        if ($request->filled('min_price')) {
            $query->where('price', '>=', (float) $request->query('min_price'));
        }
        if ($request->filled('max_price')) {
            $query->where('price', '<=', (float) $request->query('max_price'));
        }
        if ($request->filled('from')) {
            $query->where('created_at', '>=', $request->query('from'));
        }
        if ($request->filled('to')) {
            $query->where('created_at', '<=', $request->query('to') . ' 23:59:59');
        }

        $sort = $request->query('sort', 'created_at');
        $dir = $request->query('dir', 'desc') === 'asc' ? 'asc' : 'desc';
        if (in_array($sort, ['created_at', 'price', 'view_count', 'like_count'], true)) {
            $query->orderBy($sort, $dir);
        }

        return response()->json($query->paginate($this->perPage($request, 20, 100)));
    }

    public function show(string $product): JsonResponse
    {
        $p = Product::withTrashed()->findOrFail($product);
        $p->load([
            'user:id,full_name,username,avatar_url,trust_score,account_status,role,created_at,phone_number',
            'category:id,name',
            'video',
            'moderator:id,full_name',
        ]);

        $video = $p->video;
        if ($video) {
            $video->preview = $video->adminPreviewUrls();
        }

        return response()->json([
            'product' => $p,
            'raw_images' => $this->rawImages($p),
            'raw_poster' => $p->getRawOriginal('poster_url'),
            'reports' => ProductReport::where('product_id', $p->id)
                ->with('reporter:id,full_name,username,trust_score')->latest()->limit(30)->get(),
            'history' => AdminActionLog::where('target_type', 'Product')->where('target_id', $p->id)
                ->with('admin:id,full_name')->latest()->limit(30)->get(),
            'seller_stats' => [
                'products' => Product::withTrashed()->where('user_id', $p->user_id)->count(),
                'disabled' => Product::withTrashed()->where('user_id', $p->user_id)->where('status', 'disabled')->count(),
                'rejected_videos' => ProductVideo::where('user_id', $p->user_id)->where('moderation_status', 'rejected')->count(),
            ],
        ]);
    }

    public function hide(Request $request, string $product): JsonResponse
    {
        $validated = $request->validate(['reason' => $this->reasonRules()]);
        $p = Product::findOrFail($product);

        $this->moderation->hideProduct($p, $request->user(), $validated['reason']);

        return response()->json(['message' => 'Annonce masquée.', 'product' => $p->fresh()]);
    }

    public function restore(Request $request, string $product): JsonResponse
    {
        $p = Product::withTrashed()->findOrFail($product);

        if ($p->trashed()) {
            $p->restore();
        }
        $this->moderation->restoreProduct($p, $request->user(), $request->input('note'));

        return response()->json(['message' => 'Annonce réactivée.', 'product' => $p->fresh()]);
    }

    /** Suppression douce : la ligne reste en base (preuves, litiges). */
    public function destroy(Request $request, string $product): JsonResponse
    {
        $validated = $request->validate(['reason' => $this->reasonRules()]);
        $p = Product::findOrFail($product);

        $this->moderation->deleteProduct($p, $request->user(), $validated['reason']);

        return response()->json(['message' => 'Annonce supprimée (conservée pour les preuves).']);
    }

    /** Correction de contenu (retirer un texte interdit) et, pour admin+, prix et catégorie. */
    public function update(Request $request, string $product): JsonResponse
    {
        $validated = $request->validate([
            'title' => ['sometimes', 'string', 'min:2', 'max:200'],
            'description' => ['sometimes', 'nullable', 'string', 'max:5000'],
            'price' => ['sometimes', 'numeric', 'min:0'],
            'category_id' => ['sometimes', 'uuid', 'exists:categories,id'],
            'reason' => $this->reasonRules(),
        ]);

        $admin = $request->user();
        if ((isset($validated['price']) || isset($validated['category_id'])) && !$admin->hasPermission('products.force_status')) {
            return response()->json(['message' => 'Seul un administrateur peut modifier le prix ou la catégorie.'], 403);
        }

        $p = Product::withTrashed()->findOrFail($product);
        $before = $p->only(['title', 'description', 'price', 'category_id']);
        $reason = $validated['reason'];
        unset($validated['reason']);

        $p->fill($validated);
        $p->forceFill(['moderated_by' => $admin->id, 'moderated_at' => now()])->save();

        AdminLogger::log($admin, 'product_content_edited', 'Product', $p->id, [
            'reason' => $reason, 'before' => $before, 'after' => $p->only(array_keys($validated)),
        ], 'warning');

        $this->moderation->notifySeller($p->user_id, 'Votre annonce a été modifiée', "La modération a corrigé « " . mb_substr((string) $p->title, 0, 50) . " ». Motif : {$reason}");

        return response()->json(['message' => 'Annonce corrigée.', 'product' => $p->fresh()]);
    }

    public function forceStatus(Request $request, string $product): JsonResponse
    {
        $validated = $request->validate([
            'status' => ['required', 'in:draft,active,sold,reserved,expired,paused,disabled'],
            'reason' => $this->reasonRules(),
        ]);

        $p = Product::findOrFail($product);
        $old = $p->status;
        $p->forceFill(['status' => $validated['status'], 'moderated_by' => $request->user()->id, 'moderated_at' => now()])->save();

        AdminLogger::log($request->user(), 'product_status_forced', 'Product', $p->id, [
            'from' => $old, 'to' => $validated['status'], 'reason' => $validated['reason'],
        ], 'warning');

        return response()->json(['message' => 'Statut modifié.', 'product' => $p->fresh()]);
    }

    public function pin(Request $request, string $product): JsonResponse
    {
        $validated = $request->validate(['pinned' => ['required', 'boolean']]);
        $p = Product::findOrFail($product);

        $p->forceFill([
            'is_pinned' => $validated['pinned'],
            'pinned_at' => $validated['pinned'] ? now() : null,
        ])->save();

        AdminLogger::log($request->user(), $validated['pinned'] ? 'product_pinned' : 'product_unpinned', 'Product', $p->id, ['title' => $p->title]);

        return response()->json(['message' => $validated['pinned'] ? 'Annonce épinglée.' : 'Annonce désépinglée.', 'product' => $p->fresh()]);
    }

    // ─── Médias ──────────────────────────────────────────────────────────

    /** Retire une image (index dans raw_images) ou la photo de couverture. */
    public function removeImage(Request $request, string $product): JsonResponse
    {
        $validated = $request->validate([
            'target' => ['required', 'in:image,poster'],
            'index' => ['required_if:target,image', 'nullable', 'integer', 'min:0'],
            'reason' => $this->reasonRules(),
        ]);

        $p = Product::findOrFail($product);

        if ($validated['target'] === 'poster') {
            if (!$p->getRawOriginal('poster_url')) {
                return response()->json(['message' => 'Aucune photo de couverture.'], 422);
            }
            $p->forceFill(['poster_url' => null])->save();
        } else {
            $images = $this->rawImages($p);
            $idx = (int) $validated['index'];
            if (!isset($images[$idx])) {
                return response()->json(['message' => 'Image introuvable.'], 404);
            }
            array_splice($images, $idx, 1);
            $p->images = $images;
            $p->save();
        }

        $this->afterMediaChange($request, $p, 'media_removed', $validated);

        return response()->json(['message' => 'Média retiré.', 'product' => $p->fresh(), 'raw_images' => $this->rawImages($p->fresh())]);
    }

    /** Remplace une image (ou la couverture) par un fichier envoyé par le modérateur (ex. image neutre). */
    public function replaceImage(Request $request, string $product): JsonResponse
    {
        $validated = $request->validate([
            'target' => ['required', 'in:image,poster'],
            'index' => ['required_if:target,image', 'nullable', 'integer', 'min:0'],
            'file' => ['required', 'image', 'mimes:jpg,jpeg,png,webp', 'max:5120'],
            'reason' => $this->reasonRules(),
        ]);

        $p = Product::findOrFail($product);
        $path = $request->file('file')->store('products/images', 'public');

        if ($validated['target'] === 'poster') {
            $p->forceFill(['poster_url' => $path])->save();
        } else {
            $images = $this->rawImages($p);
            $idx = (int) $validated['index'];
            if (!isset($images[$idx])) {
                Storage::disk('public')->delete($path);

                return response()->json(['message' => 'Image introuvable.'], 404);
            }
            $images[$idx] = $path;
            $p->images = $images;
            $p->save();
        }

        $this->afterMediaChange($request, $p, 'media_replaced', $validated);

        return response()->json(['message' => 'Média remplacé.', 'product' => $p->fresh(), 'raw_images' => $this->rawImages($p->fresh())]);
    }

    /** Retire la vidéo d'un produit (sans sanction) : la vidéo passe en « rejected ». */
    public function removeVideo(Request $request, string $product): JsonResponse
    {
        $validated = $request->validate([
            'reason' => $this->reasonRules(),
            'strike' => ['nullable', 'boolean'],
        ]);

        $p = Product::findOrFail($product);
        $video = $p->video;
        if (!$video) {
            return response()->json(['message' => "Cette annonce n'a pas de vidéo."], 422);
        }

        $this->moderation->rejectVideo($video, $request->user(), $validated['reason'], 'rejected', 'video_only', (bool) ($validated['strike'] ?? false));

        return response()->json(['message' => 'Vidéo retirée.', 'product' => $p->fresh()->load('video')]);
    }

    // ─── Actions en masse ────────────────────────────────────────────────

    public function bulk(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'ids' => ['required', 'array', 'min:1', 'max:100'],
            'ids.*' => ['uuid'],
            'action' => ['required', 'in:hide,restore,delete'],
            'reason' => $this->reasonRules(),
        ]);

        $done = 0;
        foreach (Product::withTrashed()->whereIn('id', $validated['ids'])->get() as $p) {
            match ($validated['action']) {
                'hide' => !$p->trashed() ? $this->moderation->hideProduct($p, $request->user(), $validated['reason']) : null,
                'delete' => !$p->trashed() ? $this->moderation->deleteProduct($p, $request->user(), $validated['reason']) : null,
                'restore' => (function () use ($p, $request, $validated) {
                    if ($p->trashed()) {
                        $p->restore();
                    }
                    $this->moderation->restoreProduct($p, $request->user(), $validated['reason']);
                })(),
            };
            $done++;
        }

        return response()->json(['message' => "{$done} annonce(s) traitée(s)."]);
    }

    // ─── Helpers ─────────────────────────────────────────────────────────

    /** Chemins BRUTS stockés (l'accesseur du modèle renvoie des URLs absolues). */
    private function rawImages(Product $p): array
    {
        $raw = $p->getRawOriginal('images');
        $images = is_string($raw) ? json_decode($raw, true) : $raw;

        return is_array($images) ? array_values($images) : [];
    }

    private function afterMediaChange(Request $request, Product $p, string $action, array $validated): void
    {
        $p->forceFill(['moderated_by' => $request->user()->id, 'moderated_at' => now()])->save();

        AdminLogger::log($request->user(), $action, 'Product', $p->id, [
            'target' => $validated['target'], 'index' => $validated['index'] ?? null, 'reason' => $validated['reason'],
        ], 'warning');

        $this->moderation->notifySeller(
            $p->user_id,
            'Un média de votre annonce a été modifié',
            "« " . mb_substr((string) $p->title, 0, 50) . " » : un visuel a été " . ($action === 'media_removed' ? 'retiré' : 'remplacé') . ". Motif : {$validated['reason']}",
            null,
            ['kind' => 'product_hidden', 'concerned_admin_id' => $request->user()->id, 'contest' => ['target_type' => 'product', 'target_id' => $p->id]]
        );
    }
}
