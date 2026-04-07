<?php

namespace App\Models;

use App\Models\Traits\HasUuid;
use Illuminate\Database\Eloquent\Model;

class AdminActionLog extends Model
{
    use HasUuid;
    protected $keyType = 'string';
    public $incrementing = false;

    protected $fillable = ['admin_id', 'action', 'target_type', 'target_id', 'metadata', 'ip_address', 'severity'];

    protected function casts(): array
    {
        return ['metadata' => 'array'];
    }

    public function admin() { return $this->belongsTo(User::class, 'admin_id'); }
}
