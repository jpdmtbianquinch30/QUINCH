<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Index de performance (phase 1).
 * PostgreSQL ne crée PAS d'index automatiquement sur les clés étrangères.
 * Migration rejouable : chaque index n'est créé que s'il n'existe pas.
 */
return new class extends Migration
{
    /** @var array<string, array<string, array<int, string>>> */
    private array $indexes = [
        'products' => [
            'products_status_created_at_idx' => ['status', 'created_at'],
            'products_type_idx'              => ['type'],
            'products_category_status_idx'   => ['category_id', 'status'],
            'products_video_id_idx'          => ['video_id'],
        ],
        'messages' => [
            'messages_conversation_created_idx' => ['conversation_id', 'created_at'],
            'messages_conversation_unread_idx'  => ['conversation_id', 'is_read', 'sender_id'],
        ],
        'conversations' => [
            'conversations_buyer_last_message_idx'  => ['buyer_id', 'last_message_at'],
            'conversations_seller_last_message_idx' => ['seller_id', 'last_message_at'],
            'conversations_product_id_idx'          => ['product_id'],
        ],
        'product_likes' => [
            'product_likes_product_id_idx' => ['product_id'],
        ],
        'product_saves' => [
            'product_saves_product_id_idx' => ['product_id'],
        ],
        'favorite_items' => [
            'favorite_items_product_id_idx'    => ['product_id'],
            'favorite_items_collection_id_idx' => ['collection_id'],
        ],
        'user_follows' => [
            'user_follows_following_id_idx' => ['following_id'],
        ],
        'transactions' => [
            'transactions_order_status_created_idx' => ['order_status', 'created_at'],
            'transactions_product_id_idx'           => ['product_id'],
        ],
        'cart_items' => [
            'cart_items_reserved_until_idx' => ['reserved_until'],
        ],
        'product_videos' => [
            'product_videos_moderation_processing_idx' => ['moderation_status', 'processing_status'],
        ],
    ];

    public function up(): void
    {
        foreach ($this->indexes as $table => $indexes) {
            if (!Schema::hasTable($table)) {
                continue;
            }

            foreach ($indexes as $name => $columns) {
                if (!Schema::hasColumns($table, $columns) || Schema::hasIndex($table, $name)) {
                    continue;
                }

                Schema::table($table, function (Blueprint $t) use ($columns, $name) {
                    $t->index($columns, $name);
                });
            }
        }

        // Index partiel PostgreSQL : le feed ne lit presque que les annonces actives.
        if (DB::getDriverName() === 'pgsql'
            && Schema::hasTable('products')
            && Schema::hasColumns('products', ['status', 'created_at'])) {
            DB::statement(
                "CREATE INDEX IF NOT EXISTS products_active_created_idx
                 ON products (created_at DESC) WHERE status = 'active'"
            );
        }
    }

    public function down(): void
    {
        if (DB::getDriverName() === 'pgsql') {
            DB::statement('DROP INDEX IF EXISTS products_active_created_idx');
        }

        foreach ($this->indexes as $table => $indexes) {
            if (!Schema::hasTable($table)) {
                continue;
            }

            foreach (array_keys($indexes) as $name) {
                if (Schema::hasIndex($table, $name)) {
                    Schema::table($table, function (Blueprint $t) use ($name) {
                        $t->dropIndex($name);
                    });
                }
            }
        }
    }
};
