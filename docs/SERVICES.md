# Services QUINCH : inventaire, rôle, dépendances et pannes

Ce document répond à : « de quoi est fait QUINCH, qui fait quoi, et que se passe-t-il si un morceau tombe ? »
Mettre à jour cette page à chaque ajout ou retrait d'un service.

## Vue d'ensemble

```
                         Internet
                            │ 80 / 443
                         ┌──▼───┐   certificats Let's Encrypt automatiques
                         │Caddy │   (docker-compose.prod.yml)
                         └─┬──┬─┘
        quinch.sn          │  │          api.quinch.sn
      ┌────────────────────┘  └────────────────────┐
  ┌───▼───┐                                    ┌───▼───┐
  │  web  │  Angular + CSP                     │ nginx │  passerelle API (limites de débit,
  └───────┘                                    └───┬───┘  médias locaux si MEDIA_DRIVER=local)
                                                   │ FastCGI
        ┌─────────────┬───────────────┬────────────▼───┐
        │   queue     │ queue_videos  │      app       │  Laravel (PHP-FPM)
        │ (e-mails,   │ (FFmpeg,      │                │
        │ notifs...)  │ miniatures)   │                │
        └──────┬──────┴───────┬───────┴───────┬────────┘      ┌───────────┐
               │              │               │               │ scheduler │ tâches planifiées
        ┌──────▼──────┐  ┌────▼─────┐         │               └─────┬─────┘
        │  PostgreSQL │  │  Redis   │◄────────┴─────────────────────┘
        │ (+PgBouncer)│  │ file/cache│
        └─────────────┘  └──────────┘
   Médias ──► disque du serveur (local)  OU  stockage objet S3 ──► CDN ──► navigateurs
```

## Services du projet (conteneurs Docker)

| Service | Rôle | Image / construction | Exposé | Données persistantes | Si il tombe |
|---|---|---|---|---|---|
| `postgres` | Base de données (comptes, annonces, messages, transactions) | `postgres:16-alpine` | `127.0.0.1:5432` (tunnel SSH) | volume `postgres_data` | **Tout s'arrête** (API en erreur 503/500). Priorité n°1 des sauvegardes |
| `redis` | Cache, files d'attente, compteurs des limiteurs de débit, battement du planificateur | `redis:7-alpine` (mot de passe, 512 Mo, éviction `volatile-lru`) | interne | volume `redis_data` (AOF) | Connexions et limiteurs dégradés, **les e-mails et vidéos en attente sont perdus s'il n'a pas de persistance** : l'AOF est activé |
| `app` | Backend Laravel (PHP-FPM) ; applique les migrations et le contrôle de démarrage `quinch:preflight` | `backend/Dockerfile` | interne (port 9000) | médias locaux (`storage_data`) | API indisponible |
| `queue` | Worker de la file `default` : e-mails (codes, notifications), tâches de paiement, effacements | même image que `app` | aucun | aucune | Plus de codes e-mail ni de notifications ; les tâches s'accumulent dans Redis et repartent au redémarrage |
| `queue_videos` | Worker de la file `videos` : FFmpeg (durée, miniature). Montée en charge : `--scale queue_videos=3` | même image | aucun | aucune | Les vidéos publiées restent en « traitement » sans miniature |
| `scheduler` | Tâches planifiées : rattrapage des paiements Wave (5 min), expiration Premium, effacement des comptes supprimés, journaux, battement de santé | même image (`schedule:work`) | aucun | aucune | Paiements non rattrapés, comptes supprimés non effacés, abonnements non expirés. **Signalé par `ops/health`** |
| `nginx` | Passerelle de l'API : limites de débit, taille des envois, médias locaux, IP réelle | `nginx:1.27-alpine` | `8080` en dev ; interne en production | partage `storage_data` en lecture | API injoignable |
| `web` (prod) | Application Angular servie en fichiers statiques avec CSP | `frontend/Dockerfile` | interne (8080) | aucune | Site indisponible, l'API reste joignable |
| `caddy` (prod) | HTTPS (certificats automatiques), redirection HTTP→HTTPS, aiguillage des domaines | `caddy:2-alpine` | 80, 443 | volume `caddy_data` (certificats : ne pas perdre) | Tout est injoignable depuis Internet |
| `pgbouncer` (option) | Pool de connexions PostgreSQL | `edoburu/pgbouncer` (profil `pgbouncer`) | interne | aucune | Si activé et tombé : l'API ne joint plus la base (retirer `DB_HOST=pgbouncer`) |
| `uptime_kuma` (option) | Supervision : surveille les adresses et envoie des alertes | `louislam/uptime-kuma:1` (profil `monitoring`) | `127.0.0.1:3001` (tunnel SSH) | volume `uptime_kuma_data` | Plus d'alertes (le site, lui, continue) |
| `pgadmin` (option) | Interface de la base | `dpage/pgadmin4` (profil `tools`) | `127.0.0.1:5050` | volume `pgadmin_data` | Aucun impact sur le site. À arrêter hors usage |

Fichiers compose : `docker-compose.yml` (base), `docker-compose.prod.yml` (HTTPS + frontend), `docker-compose.ops.yml` (options d'exploitation).

## Ordre de démarrage et dépendances

`postgres` + `redis` (sains) → `app` (preflight + migrations, signale « prêt ») → `queue`, `queue_videos`, `scheduler`, `nginx` → `web` → `caddy`.
Le contrôle de démarrage de `app` **refuse de démarrer** si la configuration est dangereuse (secrets faibles, e-mail en mode `log`,
informations légales manquantes, stockage objet incomplet...). Lire ses messages : `docker compose logs app`.

## Services externes

| Service | Rôle | Configuration | Si il tombe | Remarques |
|---|---|---|---|---|
| **VPS Contabo** | Héberge tous les conteneurs | contrat Contabo | Tout | Choisir le centre de données avant la déclaration CDP (pays des serveurs) |
| **Dokploy** | Déploiement, variables d'environnement, journaux, métriques serveur | tableau de bord Dokploy | Plus de déploiement ; les conteneurs en marche continuent | Sauvegardes de bases possibles via Dokploy (voir `docs/BACKUPS.md`) |
| **Stockage objet S3 (Contabo)** | Photos, vidéos, miniatures, pièces jointes (quand `MEDIA_DRIVER=s3`) | `MEDIA_S3_*` | Médias indisponibles, envois en échec | Compatible S3, mode path-style. Voir `docs/STORAGE.md` |
| **CDN** | Sert les médias aux visiteurs (cache, vitesse) devant le stockage objet | `MEDIA_CDN_URL` | Médias lents ou indisponibles | La documentation d'un tiers indique que le trafic sortant de Contabo passe par Cloudflare et que les fichiers publics sont limités en débit : un CDN à vous devant est recommandé (à vérifier chez Contabo) |
| **Fournisseur SMTP** | Envoie les codes de réinitialisation et notifications | `MAIL_*` | Plus de codes : les utilisateurs ne peuvent pas récupérer leur compte | SPF, DKIM, DMARC obligatoires. Voir `docs/EMAIL.md` |
| **Wave** | Paiements Premium et frais d'annonce | `WAVE_*` | Paiements impossibles ; le rattrapage reprend à leur retour | API en attente d'accès. Voir `docs/PAYMENTS.md` |
| **Orange Money** | Paiements (à venir) | `ORANGE_MONEY_*` | Idem | Passerelle réelle non terminée |
| **Google Sign-In** | Connexion avec un compte Google | `GOOGLE_CLIENT_ID` | La connexion Google échoue ; e-mail + mot de passe continue | La CSP autorise `accounts.google.com/gsi` |
| **Let's Encrypt** | Certificats HTTPS (via Caddy) | `ACME_EMAIL` | Renouvellement impossible : alerte 30 jours avant l'expiration | Les DNS doivent pointer vers le serveur |
| **DNS du domaine** | `api.`, domaine principal, `www.`, `media.` | chez le registraire `.sn` | Site injoignable | Garder l'accès au compte du registraire en lieu sûr |
| **GitHub Actions** | Tests, audits de dépendances, construction des images | `.github/workflows/ci.yml` | Plus de contrôle automatique avant déploiement | Dependabot et Gitleaks y sont rattachés |

## Points de contrôle rapides

| Question | Commande |
|---|---|
| Tous les services tournent-ils ? | `docker compose ps` |
| L'application est-elle prête ? | `curl https://api.quinch.sn/up` (200) |
| Santé détaillée | `docker compose exec app php artisan quinch:health --deep` |
| Un worker est-il bloqué ? | `docker compose logs --tail=50 queue` ; tâches en échec : `docker compose exec app php artisan queue:failed` |
| Le scheduler tourne-t-il ? | `docker compose logs --tail=20 scheduler` |
| Connexions à la base | `docker compose exec postgres psql -U $POSTGRES_USER -d $POSTGRES_DB -c "select count(*) from pg_stat_activity"` |
| Espace disque | `df -h` sur le serveur ; `docker system df` |

## Variables d'environnement par service

| Service | Fichier | Variables principales |
|---|---|---|
| postgres, redis, pgbouncer, caddy | `.env` (racine) | `POSTGRES_*`, `REDIS_PASSWORD`, `REDIS_MAXMEMORY`, `API_DOMAIN`, `APP_DOMAIN`, `ACME_EMAIL` |
| app, queue, queue_videos, scheduler | `backend/.env.docker` | `APP_*`, `DB_*`, `REDIS_*`, `MAIL_*`, `MEDIA_*`, `LEGAL_*`, `WAVE_*`, `HEALTH_TOKEN`, `SESSION_*` |
| web | `docker-compose.prod.yml` | `API_ORIGIN` (déduit de `API_DOMAIN`), `CSP_HEADER_NAME` |

Un secret ne se partage jamais par e-mail ou messagerie ; on le garde dans un gestionnaire de mots de passe (voir `docs/SECURITY.md`).
