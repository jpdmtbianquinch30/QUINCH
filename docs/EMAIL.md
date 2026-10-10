# E-mail et récupération de compte

## Parcours officiel

```text
Mot de passe oublié
        ↓
Saisie de l'e-mail
        ↓
Réponse générique
        ↓
Code e-mail temporaire
        ↓
Vérification du code
        ↓
Nouveau mot de passe
```

## Règles

- TTL limité ;
- maximum de tentatives ;
- limitation du nombre de demandes ;
- invalidation du code après utilisation ;
- pas d'exposition de code dans l'API publique ;
- pas d'énumération des comptes ;
- logs sans données sensibles.

## Production

Configurer un fournisseur transactionnel SMTP ou API compatible avec Laravel.

Exemple de variables :

```text
MAIL_MAILER=smtp
MAIL_SCHEME=smtp
MAIL_HOST=...
MAIL_PORT=587
MAIL_USERNAME=...
MAIL_PASSWORD=...
MAIL_FROM_ADDRESS=no-reply@quinch.sn
MAIL_FROM_NAME=QUINCH
```

Configurer également :

- SPF ;
- DKIM ;
- DMARC.

## File d'attente

Les e-mails passent par la file `redis` : le worker `queue` doit tourner (`docker compose ps`). Si les messages ne partent plus,
regarder d'abord `docker compose logs queue --tail 50` et `queue:failed`, puis `quinch:mail-test`.

## Fournisseur conseillé pour la bêta

Gmail (mot de passe d'application) dépanne en développement mais plafonne l'envoi et classe souvent en spam. Pour la bêta
publique : un service dédié comme **Brevo** (offre gratuite d'environ 300 e-mails par jour, à vérifier chez le fournisseur),
avec un **nom de domaine à soi** pour publier SPF, DKIM et DMARC.

```text
MAIL_HOST=smtp-relay.brevo.com
MAIL_PORT=587
MAIL_FROM_ADDRESS=no-reply@votredomaine
```

Compte Gmail utilisé comme expéditeur : activer la validation en deux étapes (nécessaire au mot de passe d'application) ;
le mot de passe d'application s'écrit sans espaces dans `MAIL_PASSWORD`.

## Tests

Tester au minimum :

- compte existant ;
- compte inexistant ;
- code correct ;
- code incorrect ;
- code expiré ;
- trop de tentatives ;
- plusieurs demandes ;
- nouveau mot de passe ;
- ancienne session invalidée si prévu par le flux.

## Alerte de changement d'adresse

Quand un utilisateur change son adresse e-mail (mot de passe actuel exigé), un message d'alerte est envoyé à
**l'ancienne** adresse (« votre adresse e-mail a été modifiée »). Les autres sessions sont déconnectées et la nouvelle
adresse repasse « non confirmée ». L'envoi est tenté sans bloquer la requête : un échec est seulement journalisé.
