<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\ProductVideo;
use Illuminate\Http\Request;
use App\Support\MediaUrl;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\HttpFoundation\BinaryFileResponse;
use Symfony\Component\HttpFoundation\Response;

/**
 * Sert les vidéos du stockage avec les bons Content-Type et le support des
 * requêtes HTTP Range (avance/recul dans la vidéo).
 */
class VideoStreamController extends Controller
{
    public function stream(Request $request, string $videoId): Response
    {
        $video = ProductVideo::find($videoId);

        if (!$video || !$video->video_path) {
            abort(404, 'Video not found.');
        }

        $this->abortIfHidden($request, $video);

        // Stockage objet : le CDN sert le fichier (pas de lecture par PHP ni X-Accel).
        if (MediaUrl::isRemote()) {
            return $this->redirectToMedia($request, $video->video_path);
        }

        $disk = Storage::disk('public');
        $path = $video->video_path;

        if (!$disk->exists($path)) {
            abort(404, 'Video file not found on disk.');
        }

        $fullPath = $disk->path($path);
        $mimeType = $this->getMimeType($video->format, $fullPath);

        return $this->fileResponse($path, $fullPath, $mimeType);
    }

    /**
     * SÉCURITÉ : le paramètre `path` doit correspondre exactement au video_path
     * d'une ProductVideo en base, et le chemin réel doit rester dans le disque public.
     */
    public function streamByPath(Request $request): Response
    {
        $path = $request->query('path');

        if (!$path || str_contains($path, '..') || str_starts_with($path, '/')) {
            abort(400, 'Path parameter invalid.');
        }

        $video = ProductVideo::where('video_path', $path)->first();
        if (!$video) {
            abort(404, 'Video not found.');
        }

        $this->abortIfHidden($request, $video);

        if (MediaUrl::isRemote()) {
            return $this->redirectToMedia($request, $path);
        }

        $disk = Storage::disk('public');

        if (!$disk->exists($path)) {
            abort(404, 'Video file not found.');
        }

        $fullPath = $disk->path($path);

        $root = realpath($disk->path(''));
        $real = realpath($fullPath);
        if (!$real || !$root || !str_starts_with($real, $root)) {
            abort(404, 'Video file not found.');
        }

        $extension = pathinfo($path, PATHINFO_EXTENSION);
        $mimeType = $this->getMimeType($extension, $fullPath);

        return $this->fileResponse($path, $fullPath, $mimeType);
    }

    public function thumbnail(Request $request, string $videoId): Response
    {
        $video = ProductVideo::find($videoId);

        if (!$video || !$video->thumbnail_path) {
            abort(404, 'Thumbnail not found.');
        }

        $this->abortIfHidden($request, $video);

        if (MediaUrl::isRemote()) {
            return $this->redirectToMedia($request, $video->thumbnail_path);
        }

        $disk = Storage::disk('public');

        if (!$disk->exists($video->thumbnail_path)) {
            abort(404, 'Thumbnail file not found.');
        }

        $fullPath = $disk->path($video->thumbnail_path);

        $response = new BinaryFileResponse($fullPath);
        $response->headers->set('Content-Type', mime_content_type($fullPath) ?: 'image/jpeg');
        $response->headers->set('Cache-Control', $request->hasValidRelativeSignature() ? 'private, no-store' : 'public, max-age=604800'); // 7 jours
        $response->headers->set('Access-Control-Allow-Origin', '*');

        return $response;
    }

    /**
     * Stockage objet : redirige vers le fichier.
     *  - public : URL du CDN (mise en cache courte, la modération peut masquer la vidéo) ;
     *  - lien signé du staff (vidéo masquée au public) : URL S3 temporaire de 15 minutes.
     */
    private function redirectToMedia(Request $request, string $path): Response
    {
        if ($request->hasValidRelativeSignature()) {
            return redirect()->away(
                Storage::disk('public')->temporaryUrl($path, now()->addMinutes(15)),
                302,
                ['Cache-Control' => 'private, no-store'],
            );
        }

        return redirect()->away(
            (string) MediaUrl::for($path),
            302,
            ['Cache-Control' => 'public, max-age=300'],
        );
    }

    /**
     * Une vidéo rejetée ou mise en vérification n'est plus servie au public :
     * 404 (comme si elle n'existait pas). Le staff la visionne via une URL
     * signée à durée limitée (ProductVideo::adminPreviewUrls()).
     * Les vidéos « pending » restent visibles : publication immédiate,
     * modération après.
     */
    private function abortIfHidden(Request $request, ProductVideo $video): void
    {
        if ($video->isHiddenFromPublic() && !$request->hasValidRelativeSignature()) {
            abort(404, 'Video not found.');
        }
    }

    /**
     * - quinch.video.accel_redirect = true : PHP ne lit pas le fichier, il répond
     *   avec X-Accel-Redirect et c'est nginx qui envoie la vidéo.
     * - sinon : BinaryFileResponse (dev local sans nginx).
     */
    private function fileResponse(string $relativePath, string $fullPath, string $mimeType): Response
    {
        if (config('quinch.video.accel_redirect')) {
            $internal = rtrim((string) config('quinch.video.accel_prefix', '/_protected_storage/'), '/')
                . '/' . ltrim($relativePath, '/');

            $response = response('', 200);
            $response->headers->set('X-Accel-Redirect', $internal);
            $response->headers->set('Content-Type', $mimeType);
            $response->headers->set('Accept-Ranges', 'bytes');
            $response->headers->set('Cache-Control', 'public, max-age=86400');

            return $response;
        }

        $response = new BinaryFileResponse($fullPath);
        $response->headers->set('Content-Type', $mimeType);
        $response->headers->set('Accept-Ranges', 'bytes');
        $response->headers->set('Cache-Control', 'public, max-age=86400');
        $response->headers->set('Access-Control-Allow-Origin', '*');
        $response->headers->set('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
        $response->headers->set('Access-Control-Allow-Headers', 'Range');
        $response->headers->set('Access-Control-Expose-Headers', 'Content-Length, Content-Range');

        return $response;
    }

    private function getMimeType(?string $format, string $fullPath): string
    {
        $mimeMap = [
            'mp4' => 'video/mp4',
            'webm' => 'video/webm',
            'mov' => 'video/quicktime',
            'avi' => 'video/x-msvideo',
            'mkv' => 'video/x-matroska',
            'ogg' => 'video/ogg',
            'm4v' => 'video/mp4',
        ];

        if ($format && isset($mimeMap[strtolower($format)])) {
            return $mimeMap[strtolower($format)];
        }

        $detected = mime_content_type($fullPath);
        if ($detected && str_starts_with($detected, 'video/')) {
            return $detected;
        }

        return 'video/mp4';
    }
}
