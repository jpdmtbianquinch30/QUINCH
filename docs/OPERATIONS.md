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

## Backups

### PostgreSQL

Backup automatique quotidien minimum, avec plusieurs points de rétention.

Le backup doit être stocké hors du VPS principal.

### Test de restauration

Au moins périodiquement :

```text
backup → restauration isolée → vérification
```

## Monitoring minimum

- disponibilité HTTP ;
- erreurs 5xx ;
- CPU ;
- RAM ;
- disque ;
- PostgreSQL ;
- Redis ;
- queues ;
- temps de réponse ;
- stockage médias ;
- certificats TLS.

## Préproduction

Utiliser un environnement séparé :

```text
staging.quinch.sn
api-staging.quinch.sn
```

avec base de données et credentials séparés.

## Charge

k6 doit tester progressivement :

- connexion ;
- feed ;
- recherche ;
- marketplace ;
- profils ;
- messagerie ;
- upload ;
- webhook.

Ne pas ajouter PgBouncer ou une architecture distribuée avant d'avoir des métriques qui justifient le changement.

## Incident

En cas d'incident :

1. identifier ;
2. contenir ;
3. conserver les logs utiles ;
4. corriger ;
5. restaurer si nécessaire ;
6. vérifier ;
7. documenter la cause et le correctif.
