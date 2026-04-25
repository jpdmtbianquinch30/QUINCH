<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Jobs\ProcessVideoJob;
use App\Models\ProductVideo;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class ProductVideoController extends Controller
{
    public function upload(Request $request): JsonResponse
    {
        $request->validate([
            'video' => [
                'required',
                'file',
                'mimetypes:video/mp4,video/quicktime,video/x-msvideo,video/webm',
                'max:512000',
            ],
            'source' => ['sometimes', 'in:upload,camera'],
            'width'  => ['sometimes', 'integer'],
            'height' => ['sometimes', 'integer'],
        ], [
            'video.max'      => 'La vidéo ne doit pas dépasser 500 Mo.',
            'video.mimetypes'=> 'Format vidéo non supporté. Utilisez MP4, MOV, AVI ou WebM.',
        ]);

        $video = $request->file('video');
        $hash  = hash_file('sha256', $video->getRealPath());

        $existing = ProductVideo::where('hash_sha256', $hash)->first();
        if ($existing) {
            return response()->json([
                'message' => 'Cette vidéo existe déjà.',
                'video'   => $existing,
            ], 409);
        }

        $path        = $video->store('videos/' . date('Y/m'), 'public');
        $width       = (int) $request->input('width', 0);
        $height      = (int) $request->input('height', 0);
        $resolution  = $this->detectResolution($width, $height);
        $qualityLabel= $this->getQualityLabel($resolution);
        $source      = $request->input('source', 'upload');

        $productVideo = ProductVideo::create([
            'user_id'           => $request->user()->id,
            'video_path'        => $path,
            'thumbnail_path'    => null,
            'duration_seconds'  => null,
            'format'            => $video->getClientOriginalExtension(),
            'resolution'        => $resolution,
            'width'             => $width ?: null,
            'height'            => $height ?: null,
            'quality_label'     => $qualityLabel,
            'source'            => $source,
            'size_bytes'        => $video->getSize(),
            'hash_sha256'       => $hash,
            'processing_status' => 'pending',
            'moderation_status' => 'pending',
        ]);

        // Traitement vidéo en arrière-plan (thumbnail + durée)
        ProcessVideoJob::dispatch($productVideo);

        return response()->json([
            'message' => 'Vidéo uploadée avec succès. Traitement en cours.',
            'video'   => $productVideo,
        ], 201);
    }

    private function detectResolution(int $width, int $height): string
    {
        $maxDim = max($width, $height);
        if ($maxDim >= 3840) return '4k';
        if ($maxDim >= 1920) return '1080p';
        if ($maxDim >= 1280) return '720p';
        if ($maxDim >= 854)  return '480p';
        if ($maxDim > 0)     return '360p';
        return 'unknown';
    }

    private function getQualityLabel(string $resolution): string
    {
        return match ($resolution) {
            '4k'    => '4K Ultra HD',
            '1080p' => 'Full HD',
            '720p'  => 'HD',
            '480p'  => 'SD',
            '360p'  => 'Low',
            default => 'Standard',
        };
    }
}