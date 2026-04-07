<?php

namespace App\Models;

use App\Models\Traits\HasUuid;
use Illuminate\Database\Eloquent\Model;

class NotificationPreference extends Model
{
    use HasUuid;

    protected $keyType = 'string';
    public $incrementing = false;

    protected $fillable = [
        'user_id',
        'type',
        'push_enabled',
        'in_app_enabled',
        'email_enabled',
    ];

    protected function casts(): array
    {
        return [
            'push_enabled' => 'boolean',
            'in_app_enabled' => 'boolean',
            'email_enabled' => 'boolean',
        ];
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Default notification types with their default settings.
     */
    public static function defaultTypes(): array
    {
        return [
            'message'     => ['push' => true,  'in_app' => true,  'email' => false],
            'follow'      => ['push' => true,  'in_app' => true,  'email' => false],
            'like'        => ['push' => false, 'in_app' => true,  'email' => false],
            'comment'     => ['push' => true,  'in_app' => true,  'email' => false],
            'review'      => ['push' => true,  'in_app' => true,  'email' => true],
            'transaction' => ['push' => true,  'in_app' => true,  'email' => true],
            'system'      => ['push' => true,  'in_app' => true,  'email' => false],
            'admin'       => ['push' => true,  'in_app' => true,  'email' => true],
        ];
    }

    /**
     * Human-readable labels for each type.
     */
    public static function typeLabels(): array
    {
        return [
            'message'     => 'Messages privés',
            'follow'      => 'Abonnements',
            'like'        => 'J\'aime',
            'comment'     => 'Commentaires',
            'review'      => 'Avis',
            'transaction' => 'Transactions',
            'system'      => 'Système',
            'admin'       => 'Administration',
        ];
    }
}
