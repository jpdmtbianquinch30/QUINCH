<?php

namespace App\Models;

use App\Models\Traits\HasUuid;
use App\Models\Traits\Auditable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Transaction extends Model
{
    use HasUuid, Auditable;

    protected $keyType = 'string';
    public $incrementing = false;

    protected $fillable = [
        'buyer_id',
        'seller_id',
        'product_id',
        'amount',
        'currency',
        'payment_method',
        'payment_status',
        'order_status',
        'payment_gateway_id',
        'security_check',
        'delivery_type',
        'delivery_address',
        'transaction_fee',
        'risk_score',
        'payment_failure_count',
        'paid_at',
        'completed_at',
    ];

    protected function casts(): array
    {
        return [
            'amount' => 'float',
            'transaction_fee' => 'float',
            'risk_score' => 'float',
            'delivery_address' => 'array',
            'payment_failure_count' => 'integer',
            'paid_at' => 'datetime',
            'completed_at' => 'datetime',
        ];
    }

    public function buyer(): BelongsTo { return $this->belongsTo(User::class, 'buyer_id'); }
    public function seller(): BelongsTo { return $this->belongsTo(User::class, 'seller_id'); }
    public function product(): BelongsTo { return $this->belongsTo(Product::class); }

    public function scopePending($query) { return $query->where('payment_status', 'pending'); }
    public function scopeCompleted($query) { return $query->where('payment_status', 'completed'); }
    public function scopeSuspicious($query) { return $query->where('security_check', 'manual_review'); }

    public function getFormattedAmountAttribute(): string
    {
        return number_format($this->amount, 0, ',', '.') . ' XOF';
    }

    /** Appelé uniquement depuis un webhook vérifié — jamais depuis une requête utilisateur. */
    public function markPaid(?string $gatewayReference = null): void
    {
        $this->update([
            'payment_status' => 'completed',
            'security_check' => 'passed',
            'paid_at' => now(),
            'order_status' => 'processing',
            'payment_gateway_id' => $gatewayReference ?? $this->payment_gateway_id,
        ]);
    }

    public function markPaymentFailed(): void
    {
        $this->increment('payment_failure_count');
        $this->update([
            'payment_status' => 'failed',
            'order_status' => 'cancelled',
        ]);
    }
}
