<?php

namespace App\Support;

/**
 * Construit l'URL publique d'un média, que le fichier soit sur le disque du serveur
 * ou dans un stockage objet servi par un CDN (config media.url).
 *
 * La valeur stockée en base peut être : un chemin relatif au disque (« products/x.jpg »),
 * un chemin « /storage/... » (anciens avatars) ou déjà une URL complète.
 */
final class MediaUrl
{
    /** URL absolue d'un média (null si la valeur est vide). */
    public static function for(?string $stored): ?string
    {
        if ($stored === null || $stored === '') {
            return null;
        }

        if (preg_match('#^https?://#i', $stored)) {
            return $stored;
        }

        $path = self::path($stored);

        if ($path === null) {
            // Chemin du site qui n'est pas un média (ex. image par défaut) : inchangé.
            return url($stored);
        }

        $cdn = rtrim(trim((string) config('media.url')), '/');

        return $cdn !== '' ? $cdn . '/' . $path : url('/storage/' . $path);
    }

    /**
     * Chemin relatif au disque des médias d'une valeur stockée ou d'une URL de média
     * (locale « /storage/... » ou du CDN). null si ce n'est pas un média de QUINCH.
     */
    public static function path(?string $value): ?string
    {
        if ($value === null || $value === '') {
            return null;
        }

        $cdn = rtrim(trim((string) config('media.url')), '/');

        if ($cdn !== '' && str_starts_with($value, $cdn . '/')) {
            $path = substr($value, strlen($cdn) + 1);
        } elseif (preg_match('#^https?://#i', $value)) {
            $position = strpos($value, '/storage/');
            if ($position === false) {
                return null;
            }
            $path = substr($value, $position + strlen('/storage/'));
        } elseif (str_starts_with($value, '/storage/')) {
            $path = substr($value, strlen('/storage/'));
        } elseif (str_starts_with($value, '/')) {
            return null;
        } else {
            $path = $value;
        }

        $path = ltrim(explode('?', $path)[0], '/');

        return ($path === '' || str_contains($path, '..')) ? null : $path;
    }

    /** Vrai quand les médias sont dans un stockage objet distant (MEDIA_DRIVER=s3). */
    public static function isRemote(): bool
    {
        return config('filesystems.disks.public.driver') === 's3';
    }
}
