<?php

namespace App\Jobs;

use App\Models\CartItem;
use App\Models\Product;
use App\Models\Transaction;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Support\Facades\DB;

class ReleaseExpiredReservations implements ShouldQueue
{
    use Dispatchable, Queueable;

    public function handle(): void
    {
        Transaction::where('order_status', 'pending_payment')
            ->where('created_at', '<', now()->subMinutes(20))
            ->get()
            ->each(function (Transaction $t) {
                DB::transaction(function () use ($t) {
                    $t->update(['order_status' => 'cancelled', 'payment_status' => 'failed']);
                    $product = Product::where('id', $t->product_id)->lockForUpdate()->first();
                    if ($product) {
                        $product->increment('stock_quantity', $t->quantity ?? 1);
                        if ($product->status === 'reserved' && $product->stock_quantity > 0) {
                            $product->update(['status' => 'active']);
                        }
                    }
                });
            });

        CartItem::where('reserved_until', '<', now())->delete();
    }
}