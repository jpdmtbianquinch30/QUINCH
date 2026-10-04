<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Schéma du module Admin / Modération :
 *  - rôle `moderator`
 *  - suspension avec date de fin, avertissements (strikes), anonymisation de compte
 *  - traçabilité de modération sur produits et vidéos, suppression douce des produits
 *  - appels (contestations), liste noire de vidéos, réglages, bannières du feed
 *  - assignation / action sur signalements, expiration des bannissements d'IP
 */
return new class extends Migration
{
    public function up(): void
    {
        // ─── Rôle moderator (contrainte CHECK PostgreSQL de l'enum) ────────
        if (DB::getDriverName() === 'pgsql') {
            DB::statement('ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check');
            DB::statement("ALTER TABLE users ADD CONSTRAINT users_role_check CHECK (role IN ('user', 'moderator', 'admin', 'super_admin'))");

            // Les actions automatiques (masquage auto, 3 strikes...) n'ont pas d'admin.
            DB::statement('ALTER TABLE admin_action_logs ALTER COLUMN admin_id DROP NOT NULL');

            // Le journal d'audit doit survivre à la suppression d'un admin (avant : ON DELETE CASCADE
            // effaçait ses logs avec lui).
            DB::statement('ALTER TABLE admin_action_logs DROP CONSTRAINT IF EXISTS admin_action_logs_admin_id_foreign');
            DB::statement('ALTER TABLE admin_action_logs ADD CONSTRAINT admin_action_logs_admin_id_foreign FOREIGN KEY (admin_id) REFERENCES users(id) ON DELETE SET NULL');
        }

        // ─── users ─────────────────────────────────────────────────────────
        Schema::table('users', function (Blueprint $table) {
            if (!Schema::hasColumn('users', 'suspended_until')) {
                $table->timestamp('suspended_until')->nullable();
            }
            if (!Schema::hasColumn('users', 'suspension_reason')) {
                $table->string('suspension_reason', 500)->nullable();
            }
            if (!Schema::hasColumn('users', 'false_reports_count')) {
                $table->unsignedInteger('false_reports_count')->default(0);
            }
            if (!Schema::hasColumn('users', 'anonymized_at')) {
                $table->timestamp('anonymized_at')->nullable();
            }
        });

        // ─── products ──────────────────────────────────────────────────────
        Schema::table('products', function (Blueprint $table) {
            if (!Schema::hasColumn('products', 'moderated_by')) {
                $table->uuid('moderated_by')->nullable();
            }
            if (!Schema::hasColumn('products', 'moderated_at')) {
                $table->timestamp('moderated_at')->nullable();
            }
            if (!Schema::hasColumn('products', 'moderation_reason')) {
                $table->string('moderation_reason', 500)->nullable();
            }
            if (!Schema::hasColumn('products', 'is_pinned')) {
                $table->boolean('is_pinned')->default(false);
            }
            if (!Schema::hasColumn('products', 'pinned_at')) {
                $table->timestamp('pinned_at')->nullable();
            }
            if (!Schema::hasColumn('products', 'hidden_by_system')) {
                $table->boolean('hidden_by_system')->default(false);
            }
            if (!Schema::hasColumn('products', 'screening_flags')) {
                $table->json('screening_flags')->nullable();
            }
            if (!Schema::hasColumn('products', 'deleted_at')) {
                $table->softDeletes();
            }
        });

        // ─── product_videos ────────────────────────────────────────────────
        Schema::table('product_videos', function (Blueprint $table) {
            if (!Schema::hasColumn('product_videos', 'moderation_reason')) {
                $table->string('moderation_reason', 500)->nullable();
            }
            if (!Schema::hasColumn('product_videos', 'moderated_by')) {
                $table->uuid('moderated_by')->nullable();
            }
            if (!Schema::hasColumn('product_videos', 'moderated_at')) {
                $table->timestamp('moderated_at')->nullable();
            }
            if (!Schema::hasColumn('product_videos', 'removed_from_product_id')) {
                $table->uuid('removed_from_product_id')->nullable();
            }
        });

        // ─── signalements / tickets : assignation + action ─────────────────
        foreach (['product_reports', 'user_reports', 'support_tickets'] as $name) {
            Schema::table($name, function (Blueprint $table) use ($name) {
                if (!Schema::hasColumn($name, 'assigned_to')) {
                    $table->uuid('assigned_to')->nullable();
                }
                if (!Schema::hasColumn($name, 'action_taken')) {
                    $table->string('action_taken', 40)->nullable();
                }
                if (!Schema::hasColumn($name, 'resolved_at')) {
                    $table->timestamp('resolved_at')->nullable();
                }
            });
        }

        // ─── IP bannies : expiration ───────────────────────────────────────
        Schema::table('banned_ips', function (Blueprint $table) {
            if (!Schema::hasColumn('banned_ips', 'expires_at')) {
                $table->timestamp('expires_at')->nullable();
            }
        });

        // ─── Nouvelles tables ──────────────────────────────────────────────
        if (!Schema::hasTable('user_strikes')) {
            Schema::create('user_strikes', function (Blueprint $table) {
                $table->uuid('id')->primary();
                $table->uuid('user_id');
                $table->uuid('product_id')->nullable();
                $table->uuid('video_id')->nullable();
                $table->string('reason', 500);
                $table->uuid('issued_by')->nullable();
                $table->timestamp('expires_at')->nullable();
                $table->timestamp('revoked_at')->nullable();
                $table->timestamps();

                $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
                $table->index(['user_id', 'revoked_at']);
            });
        }

        if (!Schema::hasTable('blocked_video_hashes')) {
            Schema::create('blocked_video_hashes', function (Blueprint $table) {
                $table->uuid('id')->primary();
                $table->char('hash_sha256', 64)->unique();
                $table->string('reason', 500)->nullable();
                $table->uuid('created_by')->nullable();
                $table->timestamps();
            });
        }

        if (!Schema::hasTable('moderation_appeals')) {
            Schema::create('moderation_appeals', function (Blueprint $table) {
                $table->uuid('id')->primary();
                $table->uuid('user_id');
                $table->string('target_type', 40);          // video | product
                $table->uuid('target_id');
                $table->text('message');
                $table->string('status', 20)->default('pending'); // pending | accepted | rejected
                $table->uuid('handled_by')->nullable();
                $table->text('response')->nullable();
                $table->timestamp('handled_at')->nullable();
                $table->timestamps();

                $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
                $table->index(['status', 'created_at']);
                $table->index(['target_type', 'target_id']);
            });
        }

        if (!Schema::hasTable('site_settings')) {
            Schema::create('site_settings', function (Blueprint $table) {
                $table->string('key', 120)->primary();
                $table->json('value')->nullable();
                $table->uuid('updated_by')->nullable();
                $table->timestamps();
            });
        }

        if (!Schema::hasTable('feed_banners')) {
            Schema::create('feed_banners', function (Blueprint $table) {
                $table->uuid('id')->primary();
                $table->string('title', 150);
                $table->string('image_path', 500);
                $table->string('link_url', 500)->nullable();
                $table->boolean('is_active')->default(true);
                $table->timestamp('starts_at')->nullable();
                $table->timestamp('ends_at')->nullable();
                $table->string('city', 100)->nullable();
                $table->integer('sort_order')->default(0);
                $table->uuid('created_by')->nullable();
                $table->timestamps();

                $table->index(['is_active', 'sort_order']);
            });
        }

        // ─── Index utiles à l'admin ────────────────────────────────────────
        $this->index('admin_action_logs', 'aal_target_idx', ['target_type', 'target_id']);
        $this->index('product_videos', 'pv_moderation_created_idx', ['moderation_status', 'created_at']);
        $this->index('products', 'products_pinned_idx', ['is_pinned']);
        $this->index('product_reports', 'product_reports_status_idx', ['status', 'created_at']);
        $this->index('product_reports', 'product_reports_product_idx', ['product_id', 'status']);
        $this->index('users', 'users_role_idx', ['role']);
        $this->index('users', 'users_account_status_idx', ['account_status', 'suspended_until']);
        $this->index('users', 'users_device_fp_idx', ['device_fingerprint']);
    }

    public function down(): void
    {
        Schema::dropIfExists('feed_banners');
        Schema::dropIfExists('site_settings');
        Schema::dropIfExists('moderation_appeals');
        Schema::dropIfExists('blocked_video_hashes');
        Schema::dropIfExists('user_strikes');

        $indexes = [
            'aal_target_idx'              => 'admin_action_logs',
            'pv_moderation_created_idx'   => 'product_videos',
            'products_pinned_idx'         => 'products',
            'product_reports_status_idx'  => 'product_reports',
            'product_reports_product_idx' => 'product_reports',
            'users_role_idx'              => 'users',
            'users_account_status_idx'    => 'users',
            'users_device_fp_idx'         => 'users',
        ];
        foreach ($indexes as $name => $table) {
            if (Schema::hasTable($table) && Schema::hasIndex($table, $name)) {
                Schema::table($table, fn (Blueprint $t) => $t->dropIndex($name));
            }
        }

        Schema::table('banned_ips', function (Blueprint $table) {
            if (Schema::hasColumn('banned_ips', 'expires_at')) {
                $table->dropColumn('expires_at');
            }
        });

        foreach (['product_reports', 'user_reports', 'support_tickets'] as $name) {
            Schema::table($name, function (Blueprint $table) use ($name) {
                $cols = array_values(array_filter(
                    ['assigned_to', 'action_taken', 'resolved_at'],
                    fn ($c) => Schema::hasColumn($name, $c)
                ));
                if ($cols) {
                    $table->dropColumn($cols);
                }
            });
        }

        Schema::table('product_videos', function (Blueprint $table) {
            $cols = array_values(array_filter(
                ['moderation_reason', 'moderated_by', 'moderated_at', 'removed_from_product_id'],
                fn ($c) => Schema::hasColumn('product_videos', $c)
            ));
            if ($cols) {
                $table->dropColumn($cols);
            }
        });

        Schema::table('products', function (Blueprint $table) {
            if (Schema::hasColumn('products', 'deleted_at')) {
                $table->dropSoftDeletes();
            }
            $cols = array_values(array_filter(
                ['moderated_by', 'moderated_at', 'moderation_reason', 'is_pinned', 'pinned_at', 'hidden_by_system', 'screening_flags'],
                fn ($c) => Schema::hasColumn('products', $c)
            ));
            if ($cols) {
                $table->dropColumn($cols);
            }
        });

        Schema::table('users', function (Blueprint $table) {
            $cols = array_values(array_filter(
                ['suspended_until', 'suspension_reason', 'false_reports_count', 'anonymized_at'],
                fn ($c) => Schema::hasColumn('users', $c)
            ));
            if ($cols) {
                $table->dropColumn($cols);
            }
        });

        if (DB::getDriverName() === 'pgsql') {
            DB::statement("UPDATE users SET role = 'user' WHERE role = 'moderator'");
            DB::statement('ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check');
            DB::statement("ALTER TABLE users ADD CONSTRAINT users_role_check CHECK (role IN ('user', 'admin', 'super_admin'))");
        }
    }

    private function index(string $table, string $name, array $columns): void
    {
        if (!Schema::hasTable($table) || !Schema::hasColumns($table, $columns) || Schema::hasIndex($table, $name)) {
            return;
        }

        Schema::table($table, fn (Blueprint $t) => $t->index($columns, $name));
    }
};
