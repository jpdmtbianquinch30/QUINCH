<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Concerns\AdminHelpers;
use App\Http\Controllers\Controller;
use App\Models\Category;
use App\Services\Admin\AdminLogger;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class CategoryController extends Controller
{
    use AdminHelpers;

    public function index(): JsonResponse
    {
        $categories = Category::active()
            ->roots()
            ->with(['children' => fn ($q) => $q->active()->orderBy('sort_order')])
            ->orderBy('sort_order')
            ->get();

        return response()->json(['categories' => $categories]);
    }

    /** Vue admin : TOUTES les catégories (inactives incluses) avec le nombre de produits. */
    public function adminIndex(): JsonResponse
    {
        $all = Category::query()
            ->withCount('products')
            ->orderBy('sort_order')
            ->orderBy('name')
            ->get();

        return response()->json(['categories' => $all]);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:100'],
            'slug' => ['sometimes', 'string', 'max:150', 'unique:categories,slug'],
            'icon' => ['sometimes', 'nullable', 'string', 'max:50'],
            'description' => ['sometimes', 'nullable', 'string', 'max:500'],
            'parent_id' => ['sometimes', 'nullable', 'uuid', 'exists:categories,id'],
            'sort_order' => ['sometimes', 'integer'],
            'is_active' => ['sometimes', 'boolean'],
        ]);

        if (empty($validated['slug'])) {
            $validated['slug'] = $this->uniqueSlug($validated['name']);
        }

        if (!empty($validated['parent_id']) && ($error = $this->parentError(null, $validated['parent_id']))) {
            return response()->json(['message' => $error], 422);
        }

        $category = Category::create($validated);
        AdminLogger::log($request->user(), 'category_created', 'Category', $category->id, ['name' => $category->name]);

        return response()->json(['message' => 'Catégorie créée avec succès.', 'category' => $category], 201);
    }

    public function update(Request $request, Category $category): JsonResponse
    {
        $validated = $request->validate([
            'name' => ['sometimes', 'string', 'max:100'],
            'slug' => ['sometimes', 'string', 'max:150', 'unique:categories,slug,' . $category->id],
            'icon' => ['sometimes', 'nullable', 'string', 'max:50'],
            'description' => ['sometimes', 'nullable', 'string', 'max:500'],
            'parent_id' => ['sometimes', 'nullable', 'uuid', 'exists:categories,id'],
            'sort_order' => ['sometimes', 'integer'],
            'is_active' => ['sometimes', 'boolean'],
        ]);

        // parent_id ne peut pas pointer sur la catégorie elle-même ni sur un de ses descendants.
        if (!empty($validated['parent_id']) && ($error = $this->parentError($category, $validated['parent_id']))) {
            return response()->json(['message' => $error], 422);
        }

        $category->update($validated);
        AdminLogger::log($request->user(), 'category_updated', 'Category', $category->id, $validated);

        return response()->json(['message' => 'Catégorie mise à jour.', 'category' => $category->fresh()]);
    }

    /** Réordonnancement par glisser-déposer : liste d'ids dans le nouvel ordre. */
    public function reorder(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'ids' => ['required', 'array', 'min:1', 'max:200'],
            'ids.*' => ['uuid', 'exists:categories,id'],
        ]);

        foreach ($validated['ids'] as $position => $id) {
            Category::whereKey($id)->update(['sort_order' => $position + 1]);
        }

        AdminLogger::log($request->user(), 'categories_reordered', 'Category', null, ['count' => count($validated['ids'])]);

        return response()->json(['message' => 'Ordre enregistré.']);
    }

    public function destroy(Request $request, Category $category): JsonResponse
    {
        if ($category->products()->withTrashed()->count() > 0) {
            return response()->json([
                'message' => 'Impossible de supprimer une catégorie contenant des produits. Désactivez-la plutôt.',
            ], 422);
        }

        if ($category->children()->exists()) {
            return response()->json(['message' => 'Cette catégorie a des sous-catégories : supprimez-les ou déplacez-les d\'abord.'], 422);
        }

        AdminLogger::log($request->user(), 'category_deleted', 'Category', $category->id, ['name' => $category->name], 'warning');
        $category->delete();

        return response()->json(['message' => 'Catégorie supprimée.']);
    }

    /**
     * Deux niveaux maximum (catégorie principale > sous-catégorie) : cela
     * rend impossible tout cycle (A -> B -> A) en plus du cas parent = soi-même.
     */
    private function parentError(?Category $category, string $parentId): ?string
    {
        if ($category && $parentId === $category->id) {
            return 'Une catégorie ne peut pas être son propre parent.';
        }

        $parent = Category::find($parentId);
        if (!$parent) {
            return 'Catégorie parente introuvable.';
        }

        if ($parent->parent_id) {
            return 'Deux niveaux maximum : choisissez une catégorie principale comme parent.';
        }

        if ($category && $category->children()->exists()) {
            return 'Cette catégorie a des sous-catégories : elle ne peut pas devenir elle-même une sous-catégorie.';
        }

        return null;
    }

    private function uniqueSlug(string $name): string
    {
        $base = Str::slug($name) ?: 'categorie';
        $slug = $base;
        $i = 2;
        while (Category::where('slug', $slug)->exists()) {
            $slug = $base . '-' . $i++;
        }

        return $slug;
    }
}
