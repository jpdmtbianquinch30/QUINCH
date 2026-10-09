# Supervision : savoir qu'il y a un problème avant les utilisateurs

Trois couches, de la plus simple à la plus fine.

## 1. L'application répond-elle ? (`GET /up`)

Public, sans détail : 200 si PHP et Laravel démarrent. Utilisé par Docker (healthcheck) et par les sondes externes.

## 2. Santé détaillée (`GET /api/v1/ops/health`)

Protégée par un jeton : sans `HEALTH_TOKEN` configuré, ou avec un mauvais en-tête, la route répond **404**
(elle n'existe pas pour un inconnu).

```
curl -H "X-Health-Token: <HEALTH_TOKEN>" https://api.quinch.sn/api/v1/ops/health
curl -H "X-Health-Token: <HEALTH_TOKEN>" "https://api.quinch.sn/api/v1/ops/health?deep=1"   # teste aussi le stockage des médias
docker compose exec app php artisan quinch:health --deep                                    # depuis le serveur
```

| Contrôle | « ok » | « degraded » | « down » |
|---|---|---|---|
| `database` | requête < 500 ms | plus lente | injoignable → **HTTP 503** |
| `cache` | lecture/écriture Redis | relecture différente | Redis injoignable |
| `queue` | files < `HEALTH_QUEUE_ALERT` (1000), aucune tâche en échec dans l'heure | file longue ou tâches en échec | Redis injoignable |
| `scheduler` | battement de moins de 5 min | absent ou ancien (**le scheduler est arrêté**) | cache injoignable |
| `disk` | plus de `HEALTH_DISK_MIN_FREE` % libre (15) | moins | |
| `media` (`deep=1`) | écriture, lecture, suppression OK | | stockage injoignable |

Statut global : `ok`, `degraded` (à regarder dans la journée) ou `down` (base de données en panne : réponse 503).

## 3. Surveillance externe : Uptime Kuma

```
docker compose -f docker-compose.yml -f docker-compose.prod.yml -f docker-compose.ops.yml --profile monitoring up -d
ssh -L 3001:127.0.0.1:3001 utilisateur@serveur       puis ouvrir http://localhost:3001 (créer le compte administrateur)
```

Sondes à créer (intervalle 60 s) :

| Nom | Type | Cible | Attendu |
|---|---|---|---|
| Site | HTTP | `https://quinch.sn` | 200 |
| API | HTTP | `https://api.quinch.sn/up` | 200 |
| Santé | HTTP + en-tête `X-Health-Token` | `https://api.quinch.sn/api/v1/ops/health` | 200 et mot-clé `"status":"ok"` (ou « degraded » en avertissement) |
| Certificat HTTPS | HTTP (option « expiration du certificat ») | `https://api.quinch.sn` | alerte à 14 jours |
| Médias | HTTP | `https://media.quinch.sn/<un fichier connu>` | 200 |

Configurer au moins un **canal d'alerte** qui vous atteint vraiment (e-mail sur un autre fournisseur que celui
du site, ou Telegram). Une alerte envoyée par le site qui est tombé ne sert à rien.

Pour surveiller depuis l'extérieur du serveur (au cas où le serveur entier tombe), ajouter aussi une sonde gratuite
d'un service tiers sur `https://api.quinch.sn/up`.

## Métriques serveur

Dokploy affiche l'utilisation CPU, mémoire, disque et réseau du serveur et des conteneurs. À regarder pendant les tests
de charge (`docs/LOAD-TESTING.md`) et chaque semaine : disque (> 80 % = agir), mémoire, redémarrages de conteneurs.

## Journaux

```
docker compose logs -f --tail=100 app queue scheduler        # application
docker compose logs -f --tail=100 nginx caddy                # accès, erreurs HTTP, certificats
docker compose exec app php artisan queue:failed             # tâches en échec (le contenu est chiffré)
docker compose exec app php artisan queue:retry all          # relancer les tâches en échec
```

Les journaux d'audit d'administration sont dans l'interface admin (conservés 180 jours).

## Que faire quand une alerte arrive

1. `docker compose ps` : un conteneur est-il arrêté ou en redémarrage permanent ?
2. `quinch:health --deep` : quel contrôle est dégradé ?
3. Base ou Redis en panne → `docker compose logs --tail=50 postgres redis`, espace disque (`df -h`).
4. `degraded` sur la file → worker bloqué : `docker compose restart queue queue_videos`.
5. `degraded` sur le scheduler → `docker compose restart scheduler`.
6. Noter l'heure, la cause et la correction (utile pour la procédure d'incident, `docs/conformite/CONFORMITE_LEGALE.md`).

## Plus tard

Un suivi des erreurs applicatives (Sentry ou équivalent) et des métriques fines (Prometheus/Grafana) seront utiles quand
le trafic le justifiera : aucun des deux n'est installé aujourd'hui, pour garder le serveur simple.
