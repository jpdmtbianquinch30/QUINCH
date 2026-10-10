# Plan de test — préproduction bêta

Toutes les commandes se lancent depuis la racine du projet (`PS C:\xampp\htdocs\QUINCH>`).

## 1. Automatique (5 minutes)

```bash
docker compose up -d --build
docker compose exec app php artisan test                                  # 413 tests attendus
docker compose exec app composer audit
docker compose exec app php artisan migrate:status                        # tout « Ran »
docker compose exec app php artisan quinch:health --deep                  # « ok » partout
docker compose exec app php artisan quinch:preflight --as=production      # voir ci-dessous
cd frontend && npm ci && npm run build && npm audit --omit=dev            # build OK, 0 faille
```

`quinch:preflight --as=production` échoue sur un `.env` local (localhost, mentions légales vides, clés Wave vides) :
c'est normal. Il doit passer sur le `.env` du serveur.

## 2. Vidéos et files d'attente

```bash
docker compose ps                                                         # queue, queue_videos, scheduler : Up
docker compose exec queue_videos ls /var/www/html/storage/app/public     # le volume est bien partagé
docker compose exec app php artisan queue:failed                          # après queue:flush : liste vide
```

Puis, dans l'application : publier une vidéo, attendre quelques secondes, vérifier la miniature et la durée.
Aucune nouvelle ligne ne doit apparaître dans `queue:failed`.

## 3. Parcours manuel avec 2 comptes (vendeur A, acheteur B)

Il n'existe aucun test Angular : ce parcours est la seule vérification de l'interface.

1. **A** s'inscrit, reçoit le code e-mail, se connecte.
2. **A** publie une annonce avec vidéo (barre de progression, puis miniature).
3. **B** s'inscrit, trouve l'annonce dans le feed et la recherche, la met en favori, suit A.
4. **B** écrit à A, A répond (messagerie), B bloque puis débloque A.
5. **B** achète : paiement Wave en mode test, retour sur l'application, commande visible chez A et chez B.
6. **A** passe la commande en livrée, **B** confirme ; **B** laisse un avis.
7. Mot de passe oublié : code e-mail, nouveau mot de passe, connexion.
8. Super admin (`quinchcontact@gmail.com`) : modérer une annonce, signaler un utilisateur, créer un modérateur
   (mot de passe de 12 caractères minimum), se connecter avec lui.
9. Mobile : barre de navigation du bas, bouton Publier, lecture de la vidéo.

## 4. Sécurité rapide

```bash
bash scripts/staging-smoke-test.sh https://api-staging.quinch.sn https://staging.quinch.sn
docker ps --format "table {{.Names}}\t{{.Ports}}"     # aucun port 0.0.0.0 sauf nginx / caddy
```

## 5. Sur le serveur Linux uniquement

```bash
./scripts/backup/backup.sh
./scripts/backup/restore-test.sh
```

Une sauvegarde n'est prouvée qu'après une restauration réussie (`docs/BACKUPS.md`).
