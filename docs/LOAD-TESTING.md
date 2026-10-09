# Tests de charge (k6)

Objectif : savoir **combien d'utilisateurs simultanés** QUINCH supporte, **ce qui casse en premier**, et décider avec des
chiffres (et non au feeling) s'il faut plus de ressources, PgBouncer ou un autre découpage.

> **Toujours en préproduction** (`docs/STAGING.md`), jamais en production : un test de charge ressemble à une attaque,
> peut remplir la base de faux comptes et fait tomber le service pour de vrais utilisateurs.

## Scénarios (`load-tests/`)

| Fichier | Ce qu'il simule | Quand |
|---|---|---|
| `smoke.js` | 1 utilisateur, 30 s : le site répond-il correctement ? | Toujours en premier |
| `browse.js` | Visiteurs : fil d'actualité, liste, recherche, détail d'annonce. `PROFILE=load` (20 simultanés) ou `PROFILE=stress` (jusqu'à 200) | Test principal |
| `authenticated.js` | Utilisateurs connectés (profil, fil, notifications, conversations) avec des jetons préparés | Après `browse` |
| `login.js` | Connexions à faible cadence (le hachage coûte du CPU volontairement) | Une fois |
| `webhook-reject.js` | Faux appels de webhook Wave : doivent être refusés très vite | Une fois |

Non couvert pour l'instant (à ajouter selon vos priorités) : envoi de vidéo (volumineux, à tester à la main avec quelques
fichiers de tailles réalistes), envoi de messages, paiement de bout en bout (dépend de l'accès à l'API Wave).

## Préparer

1. Préproduction démarrée et saine (`staging-smoke-test.sh`).
2. Comptes de test et jetons : voir `docs/STAGING.md` (génère `load-tests/tokens.json`, ignoré par git).
3. Quelques annonces dans la base : publier des annonces de test, sinon les mesures du fil seront trop optimistes.

## Lancer (avec Docker, sans rien installer)

Linux / macOS :
```
docker run --rm -i -v "$PWD/load-tests:/scripts" -e API_URL=https://api-staging.quinch.sn/api/v1 grafana/k6 run /scripts/smoke.js
docker run --rm -i -v "$PWD/load-tests:/scripts" -e API_URL=https://api-staging.quinch.sn/api/v1 grafana/k6 run /scripts/browse.js
docker run --rm -i -v "$PWD/load-tests:/scripts" -e API_URL=https://api-staging.quinch.sn/api/v1 -e PROFILE=stress grafana/k6 run /scripts/browse.js
```
Windows (PowerShell), depuis la racine du projet :
```
docker run --rm -i -v "${PWD}/load-tests:/scripts" -e API_URL=https://api-staging.quinch.sn/api/v1 grafana/k6 run /scripts/smoke.js
```
Lancer les tests depuis une machine **extérieure** au serveur (votre poste ou un petit serveur dédié) pour inclure le réseau
et le HTTPS dans les mesures.

## Lire les résultats

| Mesure k6 | Objectif de départ | Lecture |
|---|---|---|
| `http_req_failed` | < 1 % | Au-dessus : erreurs 5xx ou 429. Regarder les journaux (`docker compose logs app nginx`) |
| `http_req_duration` p(95) | < 1 s | 95 % des réponses plus rapides que cela |
| `http_reqs` | — | Débit atteint (requêtes par seconde) |

Les seuils sont dans `load-tests/lib.js` : **adaptez-les à vos propres objectifs**, ce sont des points de départ.

Pendant le test, surveiller sur le serveur (Dokploy ou `docker stats`) : CPU, mémoire, et :
```
docker compose exec postgres psql -U $POSTGRES_USER -d $POSTGRES_DB -c "select count(*) from pg_stat_activity"
docker compose exec redis redis-cli -a $REDIS_PASSWORD info clients
docker compose exec app php artisan quinch:health
```

## Arbre de décision

| Constat | Action |
|---|---|
| CPU de `app` à 100 % avant la base | Plus de CPU, ou plus de workers PHP-FPM ; vérifier le cache |
| Base à 100 % CPU, requêtes lentes | Regarder les requêtes lentes, ajouter des index, **avant** tout matériel |
| Beaucoup de connexions (`pg_stat_activity` proche de `max_connections`, erreurs « too many clients ») | Activer **PgBouncer** (`docker-compose.ops.yml`, `DB_EMULATE_PREPARES=true`), refaire le test |
| Mémoire Redis saturée | Augmenter `REDIS_MAXMEMORY` ; vérifier les compteurs de limiteurs |
| Erreurs 429 en nombre | Les limiteurs (Laravel, nginx) sont stricts pour une seule IP de test : normal. Ne pas les relâcher pour « faire passer » le test sans comprendre |
| Vidéos qui restent en traitement | Monter `queue_videos` à plusieurs instances : `docker compose up -d --scale queue_videos=3` |
| Lecture lente des médias | CDN : cache, `Range`, région ; vérifier `MEDIA_CDN_URL` |

Règle : **un seul changement à la fois, puis on refait le même test** et on compare. Noter chaque résultat (date, version,
débit, p95, goulot) dans un fichier pour voir l'évolution.

## Avant l'ouverture publique

- [ ] `smoke.js` vert, `browse.js` profil `load` : seuils respectés
- [ ] `browse.js` profil `stress` : point de rupture connu et noté (nombre d'utilisateurs simultanés, premier goulot)
- [ ] `authenticated.js` et `login.js` : seuils respectés
- [ ] Supervision (`docs/MONITORING.md`) : l'alerte se déclenche bien pendant le test de rupture
- [ ] Comptes de test supprimés (`quinch:seed-load-users --purge`)
