# Préproduction (staging)

Une copie conforme de la production où l'on essaie tout **avant** les vrais utilisateurs : nouvelle version, migration,
changement de configuration, tests de charge.

## Règles

1. **Mêmes versions, même configuration, autres données.** `APP_ENV=production` aussi en préproduction : le contrôle de
   démarrage et le code exécuté sont ceux de la production.
2. **Rien en commun avec la production** : serveur (ou projet Dokploy), base, Redis, bucket de médias, secrets,
   `APP_KEY`, clés Wave/Orange Money **de test**. Une erreur en préproduction ne doit jamais toucher un vrai utilisateur.
3. **Pas de vraies données personnelles.** Ne pas copier la base de production dans la préproduction. Si c'est indispensable
   (bug impossible à reproduire autrement), anonymiser d'abord et supprimer après.
4. **Jamais de vrai argent** : paiements en mode test uniquement.
5. Domaines : `staging.quinch.sn` (site), `api-staging.quinch.sn` (API), `media-staging.quinch.sn` (médias).

## Où l'héberger

| Option | Avantage | Inconvénient |
|---|---|---|
| **Projet Dokploy séparé** (recommandé si vous utilisez déjà Dokploy) | même outil, variables d'environnement séparées, pas de conflit de ports | consomme des ressources du même serveur : les tests de charge perturberaient la production |
| **Second petit VPS** | isolation totale, tests de charge sans risque | un coût de plus |

Éviter de lancer **deux piles complètes sur le même serveur avec docker compose** : les noms de conteneurs fixes
(`quinch_*`) et les ports 80/443 de Caddy entrent en conflit. Et ne jamais faire de tests de charge sur le serveur de production.

## Mise en place

1. Créer les enregistrements DNS des trois domaines de préproduction.
2. Fichiers d'environnement : `.env` (racine, mots de passe **différents** de la production) et `backend/.env.docker`
   à partir de `backend/.env.staging.example`.
3. Démarrer : `docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build`
   (avec `API_DOMAIN=api-staging.quinch.sn`, `APP_DOMAIN=staging.quinch.sn`).
4. Contrôles automatiques :
   ```
   HEALTH_TOKEN=... ./scripts/staging-smoke-test.sh https://api-staging.quinch.sn https://staging.quinch.sn
   ```
5. Comptes de test (réservés à la préproduction, `QUINCH_ALLOW_LOADTEST_DATA=true`) :
   ```
   docker compose exec app php artisan quinch:seed-load-users 100
   docker compose exec -T app php artisan quinch:seed-load-users 100 --json > load-tests/tokens.json
   ```
   Pour les supprimer : `docker compose exec app php artisan quinch:seed-load-users --purge`.

## Parcours d'une mise en production

1. Les tests CI passent (`php artisan test`, build Angular, audits).
2. Déployer la version en préproduction.
3. `staging-smoke-test.sh` : tout au vert.
4. Parcours manuel : inscription, première connexion Google (fenêtre de consentement), mot de passe oublié (e-mail reçu),
   publication d'une annonce avec vidéo, messagerie, paiement test, export puis suppression d'un compte.
5. Si la version touche aux performances ou aux requêtes : `docs/LOAD-TESTING.md`.
6. Sauvegarde de la production **juste avant** le déploiement (`scripts/backup/backup.sh`).
7. Déployer en production, relancer `staging-smoke-test.sh` contre la production, surveiller 30 minutes (`docs/MONITORING.md`).
8. **Retour arrière** si besoin : redéployer l'image précédente. Une migration déjà appliquée ne se défait pas toute seule :
   en cas de doute, restaurer la sauvegarde de l'étape 6 (`docs/BACKUPS.md`).

## Paiements en préproduction

Utiliser exclusivement des clés de test du prestataire (Wave : en attente de l'accès à l'API ; Orange Money : à venir). Configurer le
webhook de test vers `https://api-staging.quinch.sn/api/v1/webhooks/wave`. Ne jamais enregistrer l'adresse de préproduction dans
le portail de production, ni l'inverse.
