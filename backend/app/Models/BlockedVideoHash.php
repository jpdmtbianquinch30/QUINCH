<?php

namespace App\Models;

use App\Models\Traits\HasUuid;
use Illuminate\Database\Eloquent\Model;

/** Empreinte SHA-256 d'une vidéo rejetée : empêche de la ré-uploader. */
class BlockedVideoHash extends Model
{
    use HasUuid;

    protected $keyType = 'string';
    public $incrementing = false;

    protected $fillable = ['hash_sha256', 'reason', 'created_by'];
}
