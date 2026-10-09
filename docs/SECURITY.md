# Sécurité QUINCH

## Principes

1. Le backend est l'autorité de sécurité.
2. Le frontend ne doit jamais être considéré comme fiable.
3. Aucun secret fournisseur ne doit être envoyé à Angular.
4. Les opérations sensibles doivent être authentifiées, autorisées et journalisées.
5. Les uploads sont considérés comme hostiles.

## Authentification

- E-mail + mot de passe.
- Google OAuth avec validation du token côté backend.
- Récupération par code e-mail temporaire.
- Téléphone facultatif.
- Sanctum avec expiration configurée.

## Protection des routes

Les routes sensibles utilisent :

- `auth:sanctum` ;
- rôles ;
- permissions ;
- rate limiting ;
- policies ;
- middlewares de sécurité.

## Paiements

Le paiement est confirmé uniquement après vérification serveur :

```text
signature webhook
+ référence interne
+ montant
+ devise
+ état fournisseur
+ idempotence
```

## Uploads

À vérifier systématiquement :

- taille ;
- MIME réel ;
- extension ;
- propriétaire ;
- quota ;
- nom généré ;
- emplacement non exécutable ;
- nettoyage des fichiers abandonnés.

## Headers

Le projet prévoit notamment :

- CSP / CSP Report-Only ;
- HSTS ;
- X-Frame-Options ;
- Referrer-Policy ;
- Permissions-Policy.

La CSP doit être observée avant d'être rendue bloquante sur le domaine public.

## Durcissement (phase 4, octobre 2026)

| Sujet | Règle |
|---|---|
| IP réelle | Le nginx de production (`backend/docker/nginx/production.conf`) fournit l'IP du visiteur à PHP et écrase tout `X-Forwarded-For` client. **Laisser `TRUSTED_PROXIES` vide** : avec `*`, un visiteur pourrait usurper une IP et contourner bannissements et limiteurs |
| En-têtes API | `X-XSS-Protection: 0`, CSP `default-src 'none'` sur `/api/*`, `Cache-Control: no-store` sur `/auth/*` |
| CSP du frontend | Définie dans `frontend/nginx.conf.template` ; mode observation avec `CSP_HEADER_NAME=Content-Security-Policy-Report-Only` avant de la rendre bloquante |
| TLS | Caddy (certificats Let's Encrypt automatiques) via `docker-compose.prod.yml` ; nginx n'est joignable que dans le réseau Docker |
| nginx | 64 Mo par requête (520 Mo seulement pour l'envoi de vidéo), seul `index.php` exécuté, limitation de débit large (IP partagées des réseaux mobiles), origines des médias restreintes |
| Redirection après paiement | L'en-tête `Origin` n'est accepté que s'il figure dans `CORS_ALLOWED_ORIGINS` (sinon `FRONTEND_URL`) |
| Exports CSV | Cellules neutralisées contre l'injection de formules Excel (`CsvSafe`) |
| Cookies / secrets | `quinch:preflight` refuse la production sans `SESSION_SECURE_COOKIE=true`, `SESSION_SAME_SITE` lax/strict, ni avec un mot de passe DB/Redis faible ou resté en modèle |
| Informations légales | `quinch:preflight` refuse la production sans `LEGAL_*` (éditeur, adresse, contact, hébergeur) |
| Dépendances et secrets | Dependabot, `composer audit`, `npm audit`, Gitleaks en CI |

Exploitation (phase 6) :

| Sujet | Règle |
|---|---|
| Point de santé | `/api/v1/ops/health` répond 404 sans le bon `HEALTH_TOKEN` : rien n'est révélé de l'infrastructure |
| Stockage objet | Clés d'accès dédiées au bucket (droit d'écriture limité à ce bucket), jamais les clés du compte fournisseur ; bucket de préproduction distinct |
| Sauvegardes | Dumps chiffrés (age) avant copie hors serveur ; la clé privée n'est jamais sur le serveur |
| Comptes de test | `quinch:seed-load-users` refuse de s'exécuter sans `QUINCH_ALLOW_LOADTEST_DATA=true` (préproduction uniquement) |
| Préproduction | Secrets, base, bucket et clés de paiement séparés de la production |

Risque assumé : le jeton de connexion est stocké dans `localStorage` (lisible par un script injecté). La CSP stricte
est la parade ; passer à un cookie HttpOnly changerait toute l'authentification (CSRF, application mobile).

## Secrets

Ne jamais committer :

- `.env` réel ;
- API keys ;
- webhook secrets ;
- mots de passe DB ;
- credentials OAuth ;
- credentials SMTP.

La CI utilise Gitleaks en complément des bonnes pratiques Git.

## Avant ouverture publique

- [ ] test OWASP manuel ;
- [ ] test des permissions/IDOR ;
- [ ] test upload ;
- [ ] test rate limiting ;
- [ ] test récupération compte ;
- [ ] test webhooks ;
- [ ] test logs ;
- [ ] test CSP ;
- [ ] test TLS ;
- [ ] `APP_DEBUG=false` ;
- [ ] secrets uniquement côté serveur.
