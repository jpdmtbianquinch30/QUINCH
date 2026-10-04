<?php

namespace App\Services\Admin;

use App\Models\Product;
use App\Models\SiteSetting;
use Illuminate\Support\Facades\DB;

/**
 * Pré-filtrage NON bloquant : l'annonce est publiée tout de suite, mais si elle
 * contient un mot interdit, un numéro de téléphone, un lien, qu'elle est en
 * doublon ou à prix aberrant, elle reçoit des « screening_flags » qui la font
 * remonter dans la file de modération.
 */
class ContentScreeningService
{
    public function scan(Product $product): array
    {
        $text = mb_strtolower(trim(($product->title ?? '') . ' ' . ($product->description ?? '')));
        $flags = [];

        $banned = SiteSetting::get('moderation.banned_words', []);
        if (is_array($banned)) {
            foreach ($banned as $word) {
                $word = mb_strtolower(trim((string) $word));
                if ($word !== '' && mb_strpos($text, $word) !== false) {
                    $flags[] = 'banned_word:' . $word;
                }
            }
        }

        if (SiteSetting::get('moderation.screen_phone', true)
            && preg_match('/(?:\+?221[\s.\-]?)?7[05678](?:[\s.\-]?\d){7}|\+\d{9,}/', $text)) {
            $flags[] = 'phone_number';
        }

        if (SiteSetting::get('moderation.screen_links', true)
            && preg_match('~(https?://|www\.|wa\.me/|t\.me/|bit\.ly/)~i', $text)) {
            $flags[] = 'external_link';
        }

        $duplicate = Product::query()
            ->where('user_id', $product->user_id)
            ->where('id', '!=', $product->id)
            ->whereRaw('LOWER(title) = ?', [mb_strtolower((string) $product->title)])
            ->where('created_at', '>=', now()->subDays(7))
            ->exists();
        if ($duplicate) {
            $flags[] = 'duplicate';
        }

        if ((float) $product->price > 100000000) {
            $flags[] = 'price_outlier';
        }

        return $flags;
    }

    /** Calcule et enregistre les flags (sans redéclencher les observers du modèle). */
    public function screenAndStore(Product $product): void
    {
        $flags = $this->scan($product);

        DB::table('products')->where('id', $product->id)->update([
            'screening_flags' => $flags ? json_encode($flags) : null,
        ]);
    }
}
