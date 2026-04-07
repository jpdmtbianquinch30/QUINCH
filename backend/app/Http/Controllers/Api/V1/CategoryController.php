<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Category;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CategoryController extends Controller
{
    public function index(): JsonResponse
    {
        $categories = Category::active()
            ->roots()
            ->with('children')
            ->orderBy('sort_order')
            ->get();

        return response()->json([
            'categories' => $categories,
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:100'],
            'slug' => ['sometimes', 'string', 'max:100', 'unique:categories,slug'],
            'icon' => ['sometimes', 'string', 'max:50'],
            'parent_id' => ['sometimes', 'nullable', 'exists:categories,id'],
            'sort_order' => ['sometimes', 'integer'],
            'is_active' => ['sometimes', 'boolean'],
        ]);

        if (empty($validated['slug'])) {
            $validated['slug'] = \Str::slug($validated['name']);
        }

        $category = Category::create($validated);

        return response()->json([
            'message' => 'Catégorie créée avec succès.',
            'category' => $category,
        ], 201);
    }

    public function update(Request $request, Category $category): JsonResponse
    {
        $validated = $request->validate([
            'name' => ['sometimes', 'string', 'max:100'],
            'slug' => ['sometimes', 'string', 'max:100', 'unique:categories,slug,' . $category->id],
            'icon' => ['sometimes', 'string', 'max:50'],
            'parent_id' => ['sometimes', 'nullable', 'exists:categories,id'],
            'sort_order' => ['sometimes', 'integer'],
            'is_active' => ['sometimes', 'boolean'],
        ]);

        $category->update($validated);

        return response()->json([
            'message' => 'Catégorie mise à jour.',
            'category' => $category->fresh(),
        ]);
    }

    public function destroy(Category $category): JsonResponse
    {
        // Check if category has products
        if ($category->products()->count() > 0) {
            return response()->json([
                'message' => 'Impossible de supprimer une catégorie contenant des produits.',
            ], 422);
        }

        $category->delete();

        return response()->json(['message' => 'Catégorie supprimée.']);
    }
}
