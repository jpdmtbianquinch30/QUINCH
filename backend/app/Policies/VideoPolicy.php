<?php

namespace App\Policies;

use App\Models\ProductVideo;
use App\Models\User;

class VideoPolicy
{
    public function upload(User $user): bool
    {
        return $user->account_status === 'active';
    }

    public function moderate(User $user): bool
    {
        return $user->isAdmin();
    }

    public function delete(User $user, ProductVideo $video): bool
    {
        return $user->id === $video->user_id || $user->isAdmin();
    }
}
