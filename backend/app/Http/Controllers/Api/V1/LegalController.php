<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;

/**
 * Informations légales publiques (éditeur, contact, hébergeur, versions des textes).
 * Les pages « Mentions légales », « Conditions » et « Confidentialité » du frontend
 * les affichent : la société se renseigne dans le .env, sans toucher au code.
 */
class LegalController extends Controller
{
    public function info(): JsonResponse
    {
        return response()->json([
            'publisher'     => config('legal.publisher'),
            'cdp_receipt'   => config('legal.cdp_receipt'),
            'contact_email' => config('legal.contact_email'),
            'privacy_email' => config('legal.privacy_email'),
            'hosting'       => config('legal.hosting'),
            'versions'      => config('legal.versions'),
            'retention'     => [
                'anonymized_content_days' => (int) config('legal.retention.anonymized_content_days'),
                'audit_logs_days'         => (int) config('legal.retention.audit_logs_days'),
            ],
        ]);
    }
}
