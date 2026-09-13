<?php

namespace App\Support;

use Illuminate\Http\Request;

trait ResolvesFrontendUrl
{
    /**
     * Déduit l'URL du frontend à utiliser pour les redirections post-paiement
     * (success_url/error_url) à partir de la requête entrante, plutôt que de
     * toujours utiliser la valeur figée FRONTEND_URL/config('quinch.frontend_url').
     *
     * Pourquoi : en dev, rien n'empêche d'accéder au frontend Angular via
     * localhost:4200 OU 127.0.0.1:4200 (deux origines distinctes pour le
     * navigateur, donc deux localStorage complètement séparés). Si
     * FRONTEND_URL vaut "http://localhost:4200" mais que l'utilisateur
     * navigue habituellement via "127.0.0.1:4200", chaque redirection
     * post-paiement (Wave réel ou simulateur dev) renvoie vers une origine
     * où le token de connexion n'existe pas → l'app semble déconnectée et
     * renvoie vers /auth/login juste après avoir payé, alors que la session
     * d'origine était parfaitement valide.
     *
     * On lit l'en-tête Origin (envoyé automatiquement par le navigateur sur
     * les requêtes fetch/XHR cross-origin, ce qui est le cas ici puisque le
     * frontend Angular et l'API Laravel tournent sur des ports différents)
     * et on ne retombe sur la config que si cet en-tête est absent (appel
     * serveur-à-serveur, tests, etc.).
     */
    private function resolveFrontendUrl(Request $request): string
    {
        $origin = $request->header('Origin');

        if ($origin && filter_var($origin, FILTER_VALIDATE_URL)) {
            return rtrim($origin, '/');
        }

        return rtrim(config('quinch.frontend_url'), '/');
    }
}
