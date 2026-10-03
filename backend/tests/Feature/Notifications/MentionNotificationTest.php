<?php

namespace Tests\Feature\Notifications;

use App\Models\Product;
use App\Models\User;
use App\Models\UserNotification;
use App\Services\NotificationService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class MentionNotificationTest extends TestCase
{
    use RefreshDatabase;

    public function test_mentioned_users_are_notified_but_not_the_author(): void
    {
        $author = User::factory()->create(['username' => 'auteur_test']);
        $mentioned = User::factory()->create(['username' => 'cible_test', 'account_status' => 'active']);

        $product = Product::factory()->create([
            'user_id' => $author->id,
            'title' => 'Super offre avec @cible_test et @auteur_test',
        ]);

        app(NotificationService::class)->notifyMentions($product, $author);

        $this->assertSame(1, UserNotification::where('user_id', $mentioned->id)->where('type', 'mention')->count());
        $this->assertSame(0, UserNotification::where('user_id', $author->id)->where('type', 'mention')->count());
    }

    public function test_unknown_usernames_do_not_break_anything(): void
    {
        $author = User::factory()->create();
        $product = Product::factory()->create(['user_id' => $author->id, 'title' => 'Salut @personne_inconnue']);

        app(NotificationService::class)->notifyMentions($product, $author);

        $this->assertSame(0, UserNotification::where('type', 'mention')->count());
    }
}
