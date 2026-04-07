<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Product;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ShareController extends Controller
{
    public function track(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'product_id' => 'required|exists:products,id',
            'platform' => 'required|in:whatsapp,facebook,instagram,sms,copy_link,qr_code',
        ]);

        $product = Product::findOrFail($validated['product_id']);
        $product->increment('share_count');

        return response()->json([
            'message' => 'Partage enregistré.',
            'share_count' => $product->share_count,
            'share_url' => url("/product/{$product->slug}"),
        ]);
    }

    public function getShareData(Request $request, Product $product): JsonResponse
    {
        return response()->json([
            'url' => url("/product/{$product->slug}"),
            'title' => $product->title,
            'description' => substr($product->description ?? '', 0, 150),
            'price' => $product->formatted_price,
            'image' => $product->video?->thumbnail,
            'platforms' => [
                ['id' => 'whatsapp', 'name' => 'WhatsApp', 'icon' => 'chat', 'url' => 'https://wa.me/?text=' . urlencode($product->title . ' - ' . url("/product/{$product->slug}"))],
                ['id' => 'facebook', 'name' => 'Facebook', 'icon' => 'facebook', 'url' => 'https://www.facebook.com/sharer/sharer.php?u=' . urlencode(url("/product/{$product->slug}"))],
                ['id' => 'copy_link', 'name' => 'Copier le lien', 'icon' => 'link'],
                ['id' => 'sms', 'name' => 'SMS', 'icon' => 'sms', 'url' => 'sms:?body=' . urlencode($product->title . ' ' . url("/product/{$product->slug}"))],
            ],
        ]);
    }
}
