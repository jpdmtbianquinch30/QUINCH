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
            ->chunkById(200, function ($transactions) {
                foreach ($transactions as $t) {
                    DB::transaction(function () use ($t) {
                        // Relecture SOUS VERROU : un webhook Wave a pu marquer la
                        // transaction payée entre la sélection et ici.
                        $fresh = Transaction::where('id', $t->id)->lockForUpdate()->first();
                        if (!$fresh
                            || $fresh->order_status !== 'pending_payment'
                            || $fresh->payment_status === 'completed') {
                            return;
                        }

                        $fresh->update(['order_status' => 'cancelled', 'payment_status' => 'failed']);

                        $product = Product::where('id', $fresh->product_id)->lockForUpdate()->first();
                        if ($product) {
                            $product->increment('stock_quantity', $fresh->quantity ?? 1);
                            if ($product->status === 'reserved' && $product->stock_quantity > 0) {
                                $product->update(['status' => 'active']);
                            }
                        }
                    });
                }
            });

        CartItem::where('reserved_until', '<', now())->delete();
    }
}
