<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class UserFollow extends Model
{
    /**
     * Cette table n'a pas de colonne "id" : sa clé primaire est composite
     * (follower_id + following_id, voir la migration). Sans $incrementing =
     * false, Eloquent tente un INSERT ... RETURNING "id" qui échoue toujours
     * (colonne inexistante) — bug réel, pas seulement lié aux tests.
     */
    public $incrementing = false;
    protected $primaryKey = null;

    protected $fillable = ['follower_id', 'following_id', 'notifications_enabled'];

    public function follower() { return $this->belongsTo(User::class, 'follower_id'); }
    public function following() { return $this->belongsTo(User::class, 'following_id'); }
}
