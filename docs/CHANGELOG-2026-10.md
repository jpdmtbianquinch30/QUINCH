# QUINCH — mise à jour documentation/design — octobre 2026

## Documentation

- README racine réécrit comme documentation de référence.
- Architecture, API, sécurité, e-mail, paiements, exploitation, conformité et UI documentés.
- Les anciennes instructions utilisateur imposant un OTP SMS ont été retirées du guide public.
- Le modèle actuel est documenté : e-mail principal, téléphone facultatif, récupération par e-mail.
- Les paiements utilisateurs-à-utilisateurs sont explicitement hors périmètre.

## Design

- Nouveau système visuel QUINCH : bleu nuit + violet/indigo/bleu/cyan.
- Surfaces plus sobres et plus lisibles.
- Boutons, champs, cartes, modales et badges harmonisés.
- Touch targets renforcés sur mobile.
- Modales adaptées aux petits écrans.
- Respect de `prefers-reduced-motion`.
- Navigation Angular et routes conservées.
- Aucun service métier ou flux fonctionnel volontairement modifié par le redesign.

## Sécurité (phase 4)

- En-têtes API durcis, CSP du frontend, TLS via Caddy, nginx de production, contrôle de démarrage étendu
  (cookies, secrets faibles), `TRUSTED_PROXIES` laissé vide, redirection de paiement limitée aux origines CORS,
  protection des exports CSV, Dependabot et Gitleaks. Voir `docs/SECURITY.md`.

## Conformité légale (phase 5)

- Pages publiques conditions / confidentialité / mentions légales, informations de l'éditeur pilotées par `.env`.
- Consentement mémorisé (date + version) à l'inscription ; **étape de consentement explicite** à la première
  connexion Google.
- Export de données complet et corrigé (l'ancien plantait), effacement du compte complété, effacement définitif
  différé des contenus (30 jours), durées de conservation configurables.
- Docs : `docs/LEGAL.md`, `docs/conformite/`.

## Design

- Listes déroulantes natives (`<select>`) : texte blanc sur fond blanc dans l'admin corrigé par une règle globale
  (`color-scheme` + fond opaque des `<option>`), thème sombre et clair.

## Charge et exploitation (phase 6)

- **Stockage objet + CDN** : `MEDIA_DRIVER=s3` (disque `public` basculé sans changer les appels de fichiers), `MEDIA_CDN_URL`,
  `App\Support\MediaUrl` pour toutes les URL de médias, lecture des vidéos par redirection vers le CDN, miniatures FFmpeg
  depuis une URL S3 temporaire, `quinch:media-migrate`, effacement RGPD compatible CDN. Voir `docs/STORAGE.md`.
- **Supervision** : `GET /api/v1/ops/health` (jeton), `quinch:health`, battement du scheduler, Uptime Kuma (`docker-compose.ops.yml`).
- **Sauvegardes** : `scripts/backup/backup.sh` et `restore-test.sh` (dump vérifié, chiffrement age, rclone, rotation).
- **Tests de charge** : scénarios k6 dans `load-tests/`, `quinch:seed-load-users` (préproduction uniquement).
- **PgBouncer** : service optionnel et `DB_EMULATE_PREPARES` prêts, à activer seulement si les mesures le justifient.
- **Préproduction** : `backend/.env.staging.example`, `scripts/staging-smoke-test.sh`, procédure de mise en production.
- **Docs** : `docs/SERVICES.md` (inventaire des services), `STORAGE`, `MONITORING`, `BACKUPS`, `STAGING`, `LOAD-TESTING`.
