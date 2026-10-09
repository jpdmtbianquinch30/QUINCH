# Sauvegardes et restauration

Une sauvegarde qui n'a jamais été restaurée n'est pas une sauvegarde. Ce document décrit quoi sauvegarder, comment, et
comment vérifier.

## Ce qui doit être sauvegardé

| Élément | Où il vit | Sauvegarde | Remarque |
|---|---|---|---|
| **Base PostgreSQL** | volume `postgres_data` | `scripts/backup/backup.sh` quotidien, copie hors serveur | Le plus important : comptes, annonces, messages, paiements |
| **Médias** (photos, vidéos) | bucket S3 (ou disque local) | copie périodique vers un autre fournisseur ou une autre région | Un stockage objet n'est pas une sauvegarde (suppression par erreur, compte fournisseur compromis) |
| **Secrets** (`.env`, `backend/.env.docker`) | serveur | gestionnaire de mots de passe, **pas** dans git | Sans eux, une sauvegarde de la base ne suffit pas à relancer le site (`APP_KEY` notamment) |
| **Certificats HTTPS** | volume `caddy_data` | inutile : régénérés automatiquement | Éviter de supprimer ce volume (limites de Let's Encrypt) |
| Redis | volume `redis_data` | non | Cache et files : se reconstruisent |

Objectifs à viser pour la bêta : perte maximale de données (**RPO**) 24 h, reprise (**RTO**) quelques heures. À resserrer
quand le trafic le justifie (sauvegarde plus fréquente, archivage WAL).

## Sauvegarde de la base

```
./scripts/backup/backup.sh
```

Ce que fait le script : `pg_dump` au format compressé, **vérification** (`pg_restore --list`), chiffrement optionnel
avec **age**, empreinte SHA-256, copie hors serveur avec **rclone**, rotation locale.

Réglages (variables d'environnement) : `BACKUP_DIR` (défaut `/var/backups/quinch`), `BACKUP_KEEP_DAILY` (14),
`BACKUP_AGE_RECIPIENT`, `RCLONE_REMOTE`, `REMOTE_KEEP_DAYS` (30).

### Chiffrement (recommandé : le dump contient des données personnelles)

```
age-keygen -o cle-privee-backup.txt          # sur VOTRE poste, jamais sur le serveur
```
Garder `cle-privee-backup.txt` dans un gestionnaire de mots de passe **et** une copie hors ligne. Le serveur ne reçoit que la
clé publique (ligne `# public key: age1...`) : `BACKUP_AGE_RECIPIENT=age1...`. Sans la clé privée, les sauvegardes sont
inutilisables : la perdre revient à ne pas avoir de sauvegarde.

### Copie hors serveur

Une sauvegarde sur le disque du serveur ne protège pas de la perte du serveur. Avec **rclone** (installé sur le serveur) :
```
rclone config                                # créer une destination S3, ex. « contabo », avec les clés du fournisseur
RCLONE_REMOTE=contabo:quinch-backups ./scripts/backup/backup.sh
```
Utiliser un bucket **distinct** de celui des médias, idéalement chez un autre fournisseur ou dans une autre région.

### Planification (cron)

```
crontab -e
0 3 * * * cd /opt/quinch && BACKUP_AGE_RECIPIENT=age1... RCLONE_REMOTE=contabo:quinch-backups ./scripts/backup/backup.sh >> /var/log/quinch-backup.log 2>&1
```
Vérifier chaque semaine que le fichier du jour existe et que le journal ne contient pas « ERREUR ».

### Alternative Dokploy

Dokploy propose des sauvegardes planifiées de bases vers un stockage S3. Si vous l'utilisez, gardez quand même un **test
de restauration** (ci-dessous) et vérifiez le chiffrement et la durée de conservation.

## Test de restauration (au moins une fois par mois)

```
./scripts/backup/restore-test.sh /var/backups/quinch/quinch-20261008-030000.dump
AGE_IDENTITY=cle-privee-backup.txt ./scripts/backup/restore-test.sh quinch-20261008-030000.dump.age
```
Le script vérifie l'empreinte, déchiffre, restaure dans une base temporaire `quinch_restore_test`, compte utilisateurs,
annonces et migrations, puis supprime la base temporaire. **Il ne touche jamais à la base de production.**

## Restaurer après un sinistre

1. Nouveau serveur ou volume : relancer `postgres` seul (`docker compose up -d postgres`).
2. Récupérer la sauvegarde (et la clé privée age), la déchiffrer.
3. Recréer la base vide puis restaurer :
   ```
   docker compose exec -T postgres createdb -U $POSTGRES_USER $POSTGRES_DB
   docker compose exec -T postgres pg_restore -U $POSTGRES_USER -d $POSTGRES_DB --no-owner < quinch-....dump
   ```
4. Remettre les secrets (`APP_KEY` identique : sinon sessions et tâches chiffrées en attente sont illisibles).
5. Démarrer le reste (`docker compose up -d`), lancer `quinch:health --deep`, tester connexion, feed, lecture d'une vidéo.
6. Noter la durée totale : c'est votre vrai RTO.

## Conformité : données supprimées et sauvegardes

Quand un utilisateur supprime son compte, ses données disparaissent de la base (immédiatement pour l'identité, après 30 jours
pour les contenus). Elles **restent dans les sauvegardes jusqu'à leur expiration** (environ 30 jours avec les réglages par
défaut). C'est acceptable à condition de le dire et de ne pas conserver les sauvegardes plus longtemps : c'est mentionné dans
`docs/conformite/REGISTRE_TRAITEMENTS.md`.

**Si une sauvegarde est restaurée**, les comptes supprimés APRÈS cette sauvegarde réapparaissent. Il faut refaire leur
suppression : le journal d'administration (conservé 180 jours) liste les suppressions de comptes. Le scheduler efface ensuite
leurs contenus comme d'habitude.

## Sauvegarde des médias (stockage objet)

Copie périodique vers un second bucket (autre fournisseur ou région) avec rclone :
```
rclone sync contabo:quinch-media autre:quinch-media-backup --backup-dir autre:quinch-media-deleted
```
`--backup-dir` garde les fichiers supprimés ou remplacés à part : **les purger après 30 jours** (`rclone delete ... --min-age 30d`),
sinon un contenu effacé à la demande d'un utilisateur resterait indéfiniment dans vos copies.
