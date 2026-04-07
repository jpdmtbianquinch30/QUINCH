<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\ProductVideo;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\HttpFoundation\StreamedResponse;
use Symfony\Component\HttpFoundation\BinaryFileResponse;

/**
 * VideoStreamController
 *
 * Serves video files from storage with proper Content-Type headers
 * and supports HTTP Range requests for seeking/streaming.
 */
class VideoStreamController extends Controller
{
    /**
     * Stream a video by its ID.
     */
    public function stream(string $videoId): BinaryFileResponse|StreamedResponse
    {
        $video = ProductVideo::find($videoId);

        if (!$video || !$video->video_path) {
            abort(404, 'Video not found.');
        }

        $disk = Storage::disk('public');
        $path = $video->video_path;

        if (!$disk->exists($path)) {
            abort(404, 'Video file not found on disk.');
        }

        $fullPath = $disk->path($path);
        $mimeType = $this->getMimeType($video->format, $fullPath);
        $fileSize = $disk->size($path);

        // Return a BinaryFileResponse which handles Range requests automatically
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

    /**
     * Stream a video by direct path (for storage paths).
     */
    public function streamByPath(Request $request): BinaryFileResponse
    {
        $path = $request->query('path');

        if (!$path) {
            abort(400, 'Path parameter required.');
        }

        $disk = Storage::disk('public');

        if (!$disk->exists($path)) {
            abort(404, 'Video file not found.');
        }

        $fullPath = $disk->path($path);
        $extension = pathinfo($path, PATHINFO_EXTENSION);
        $mimeType = $this->getMimeType($extension, $fullPath);

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

    /**
     * Serve a thumbnail image for a video.
     */
    public function thumbnail(string $videoId): BinaryFileResponse
    {
        $video = ProductVideo::find($videoId);

        if (!$video || !$video->thumbnail_path) {
            abort(404, 'Thumbnail not found.');
        }

        $disk = Storage::disk('public');

        if (!$disk->exists($video->thumbnail_path)) {
            abort(404, 'Thumbnail file not found.');
        }

        $fullPath = $disk->path($video->thumbnail_path);

        $response = new BinaryFileResponse($fullPath);
        $response->headers->set('Content-Type', mime_content_type($fullPath) ?: 'image/jpeg');
        $response->headers->set('Cache-Control', 'public, max-age=604800'); // 7 days
        $response->headers->set('Access-Control-Allow-Origin', '*');

        return $response;
    }

    /**
     * Get MIME type for video format.
     */
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

        // Fallback to file detection
        $detected = mime_content_type($fullPath);
        if ($detected && str_starts_with($detected, 'video/')) {
            return $detected;
        }

        return 'video/mp4'; // safe default
    }
}
