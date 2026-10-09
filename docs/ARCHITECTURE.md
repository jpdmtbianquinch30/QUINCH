# Architecture QUINCH

## Objectif

Conserver une architecture simple, maintenable par une petite équipe — actuellement un développeur — tout en permettant d'augmenter progressivement la capacité.

## Composants

### Frontend

Angular 20, standalone components, Router, services métier, guards et interceptors.

Le frontend ne possède jamais les secrets des fournisseurs de paiement ou de messagerie. Il consomme l'API Laravel.

### Backend

Laravel 12 / PHP 8.2+.

Organisation principale :

```text
Controllers
   ↓
Form validation / Middleware / Policies
   ↓
Services
   ↓
Models / DB
```

Les traitements lourds passent par Redis + workers.

La logique de paiement des commandes est isolée dans `App\Services\Payments\OrderPaymentConfirmer` (verrou, idempotence, contrôle du montant), appelée par les webhooks Wave et Orange Money ; Premium et frais de publication passent par `WavePaymentConfirmer`.

### Données

PostgreSQL 16.

Redis 7 sert à :

- cache ;
- sessions ;
- files d'attente ;
- compteurs/rate limiting selon configuration.

### Médias

Par défaut, le disque local (volume Docker) est utilisé : acceptable pour le développement et une très petite bêta. Pour la production durable, `MEDIA_DRIVER=s3` bascule les médias vers un stockage objet servi par un CDN, sans changer le code applicatif (voir `docs/STORAGE.md`). Inventaire de tous les services : `docs/SERVICES.md`.

## Pourquoi ne pas passer en microservices

QUINCH est encore dans une phase de validation. Les domaines métier sont suffisamment séparés dans Laravel pour évoluer sans payer immédiatement le coût opérationnel des microservices.

Une extraction ne doit être faite qu'après identification d'un besoin réel : charge, isolation, équipe séparée ou dépendance technique spécifique.

## Flux de production

```text
Utilisateur
    ↓
Cloudflare / DNS
    ↓
Caddy HTTPS
    ├──→ Angular/Nginx
    └──→ API Nginx
              ↓
           Laravel
          /   |   \
     PostgreSQL Redis Queue
                    ↓
                FFmpeg/jobs
```

## Scalabilité progressive

Ordre recommandé :

1. pagination/indexation ;
2. cache Redis ;
3. queues ;
4. Object Storage ;
5. CDN ;
6. monitoring ;
7. optimisation DB ;
8. PgBouncer seulement si nécessaire ;
9. séparation de services uniquement si une charge réelle le justifie.
