# Exploitation QUINCH

## Production cible

- VPS Contabo ;
- Dokploy pour le déploiement si retenu ;
- Cloudflare pour DNS/protection ;
- Docker Compose ;
- Caddy ;
- PostgreSQL ;
- Redis ;
- Object Storage + CDN pour les médias.

## Déploiement

1. Tester en CI.
2. Construire les images.
3. Déployer en préproduction.
4. Exécuter les smoke tests.
5. Vérifier `quinch:preflight`.
6. Migrer la production.
7. Vérifier healthchecks.
8. Surveiller les erreurs.

## Mise à jour du code en Docker

Le code est copié dans l'image : un changement local n'a aucun effet tant que l'image n'est pas reconstruite.

```bash
docker compose up -d --build app queue queue_videos scheduler
docker compose exec app php artisan migrate --force
docker compose exec app php artisan config:clear
docker compose exec app php artisan quinch:health --deep
```

Avec Docker, la file doit être `redis` (`QUEUE_CONNECTION=redis`). Une file `database` ou un worker arrêté laisse
notifications à tous et e-mails en attente. Contrôle : `docker compose exec app php artisan queue:failed` (liste vide).

## Production HTTPS

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build
```

Variables du `.env` racine : `API_DOMAIN`, `APP_DOMAIN`, `ACME_EMAIL`. Docker Compose 2.24.4 ou plus requis.
Les DNS (`api.`, domaine principal, `www.`) doivent pointer vers le serveur, ports 80 et 443 ouverts.
Voir `docs/SECURITY.md` pour la CSP et les réglages de proxy.

## Tâches planifiées (conformité)

- `PurgeAnonymizedAccountData` (quotidienne) : efface définitivement annonces, médias et messages des comptes
  supprimés depuis plus de `LEGAL_ANONYMIZED_CONTENT_DAYS` jours.
- `PurgeExpiredAdminData` (quotidienne) : journaux techniques plus vieux que `LEGAL_AUDIT_LOGS_DAYS` jours.

Le worker `queue` et le scheduler doivent tourner. Lors du passage au stockage objet (phase 6), vérifier que
l'effacement des fichiers (annonces, vidéos, pièces jointes des messages) utilise le nouveau disque.

## Backups

Détail complet : `docs/BACKUPS.md`.

- PostgreSQL : `scripts/backup/backup.sh` (dump vérifié, chiffrement age, copie hors serveur avec rclone, rotation), planifié en cron ;
- test de restauration au moins une fois par mois : `scripts/backup/restore-test.sh` (base temporaire, jamais la production) ;
- médias : copie périodique du bucket vers un autre fournisseur ; secrets : gestionnaire de mots de passe.

## Monitoring

Détail complet : `docs/MONITORING.md`.

- `GET /up` (public) et `GET /api/v1/ops/health` (jeton `HEALTH_TOKEN`) : base, Redis, files, scheduler, disque, médias ;
- `php artisan quinch:health --deep` depuis le serveur ;
- Uptime Kuma (`docker-compose.ops.yml`, profil `monitoring`) pour les alertes ; Dokploy pour les métriques CPU, RAM, disque ;
- à surveiller en plus : erreurs 5xx, certificats TLS, tâches en échec (`queue:failed`).

## Stockage objet et CDN

Détail complet : `docs/STORAGE.md`. `MEDIA_DRIVER=s3` bascule les médias vers le bucket S3, `MEDIA_CDN_URL` donne l'adresse publique,
`php artisan quinch:media-migrate` copie les fichiers existants.

## Préproduction

Détail complet : `docs/STAGING.md`. Environnement séparé (`staging.quinch.sn`, `api-staging.quinch.sn`) avec base, Redis, bucket,
secrets et clés de paiement de test **distincts** de la production. Contrôle après déploiement : `scripts/staging-smoke-test.sh`.

## Charge

Détail complet : `docs/LOAD-TESTING.md`. Scénarios k6 dans `load-tests/` (fumée, navigation, utilisateurs connectés, connexion,
faux webhook), à lancer **uniquement en préproduction**. Comptes de test : `php artisan quinch:seed-load-users`.

### PgBouncer : quand l'ajouter

Pas avant d'avoir des chiffres. Si les tests de charge montrent que les connexions à PostgreSQL sont le goulot
(`pg_stat_activity` proche de `max_connections`, erreurs « too many clients ») :

1. démarrer le service : `docker compose -f docker-compose.yml -f docker-compose.prod.yml -f docker-compose.ops.yml --profile pgbouncer up -d pgbouncer` ;
2. dans `backend/.env.docker` : `DB_HOST=pgbouncer` et `DB_EMULATE_PREPARES=true` (obligatoire en mode « transaction ») ;
3. redémarrer `app`, `queue`, `queue_videos`, `scheduler` ;
4. refaire le même test de charge et comparer.

Retour arrière : remettre `DB_HOST=postgres` et `DB_EMULATE_PREPARES=false`, puis redémarrer ces quatre services.
Laravel y est déjà préparé (`config/database.php`). Ne pas ajouter d'architecture distribuée sans mesures.

## Services

Inventaire de chaque service (conteneurs et services externes), rôle, dépendances et conséquence d'une panne : `docs/SERVICES.md`.

## Incident

En cas d'incident :

1. identifier ;
2. contenir ;
3. conserver les logs utiles ;
4. corriger ;
5. restaurer si nécessaire ;
6. vérifier ;
7. documenter la cause et le correctif.
