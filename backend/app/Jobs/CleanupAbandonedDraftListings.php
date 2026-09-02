<?php

namespace App\Jobs;

use App\Models\Product;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;

class CleanupAbandonedDraftListings implements ShouldQueue
{
    use Dispatchable, Queueable;

    public function handle(): void
    {
        $abandoned = Product::where('status', 'draft')
            ->whereIn('listing_fee_status', ['pending', 'failed'])
            ->where('created_at', '<', now()->subHours(24))
            ->get();

        foreach ($abandoned as $product) {
            $this->deleteFiles($product);

            DB::transaction(function () use ($product) {
                $product->delete();
            });

            Log::info('Annonce brouillon abandonnée supprimée (frais de publication impayé)', [
                'product_id' => $product->id,
                'user_id' => $product->user_id,
            ]);
        }
    }

    private function deleteFiles(Product $product): void
    {
        $posterPath = $product->getRawOriginal('poster_url');
        if ($posterPath) {
            Storage::disk('public')->delete($posterPath);
        }

        $rawImages = $product->getRawOriginal('images');
        $imagePaths = $rawImages ? (json_decode($rawImages, true) ?? []) : [];

        foreach ($imagePaths as $imagePath) {
            Storage::disk('public')->delete($imagePath);
        }
    }
}