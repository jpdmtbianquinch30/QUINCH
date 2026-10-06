# Réception des codes par e-mail (QUINCH)

Le code « mot de passe oublié » (6 chiffres, valable `QUINCH_OTP_TTL_MINUTES` minutes) est envoyé
par e-mail, **par la file d'attente** : l'API répond tout de suite, un worker envoie le message.

```
POST /auth/forgot-password → OtpService::issue() → Mail::queue(PasswordResetCodeMail)
                                                        │ (chiffré dans Redis, 3 tentatives : 10 s puis 60 s)
                                              worker « queue » → SMTP du fournisseur → boîte du client
```

## 1. Tester sa configuration (à faire AVANT d'ouvrir au public)

```bat
cd backend
php artisan config:clear
php artisan quinch:mail-test vous@gmail.com           :: envoi direct : valide le SMTP
php artisan quinch:mail-test vous@gmail.com --queue   :: via la file : valide aussi le worker
```

La commande affiche le transport, le serveur, le schéma et l'expéditeur (jamais le mot de passe) et
explique l'échec le cas échéant. Avec `MAIL_MAILER=log`, elle prévient qu'aucun e-mail réel ne part.

## 2. Développement local

| Besoin | Réglage `.env` |
|---|---|
| Lire le code sans SMTP | `MAIL_MAILER=log` : le message est écrit dans `storage/logs/laravel.log` |
| Pas de worker lancé | `QUEUE_CONNECTION=sync` (envoi immédiat) **ou** `php artisan queue:work` dans un 2e terminal |
| Tester un vrai SMTP | `MAIL_MAILER=smtp` + `MAIL_HOST/PORT/USERNAME/PASSWORD` + `quinch:mail-test` |

Avec `QUEUE_CONNECTION=database` et aucun worker, **aucun e-mail ne part** (le message attend dans la
table `jobs`) : c'est la cause n°1 de « je ne reçois rien » en local. Le code n'est jamais renvoyé par
l'API hors tests automatisés.

## 3. Production (`backend/.env.docker`)

1. Choisir un service d'envoi transactionnel (SMTP) et créer un identifiant SMTP dédié.
2. Renseigner `MAIL_MAILER=smtp`, `MAIL_HOST`, `MAIL_PORT`, `MAIL_USERNAME`, `MAIL_PASSWORD`.
3. `MAIL_SCHEME` : `smtp` avec le port **587** (STARTTLS) ou `smtps` avec le port **465** (TLS direct).
   Pas d'autre valeur.
4. `MAIL_FROM_ADDRESS` : une adresse **de votre domaine** (ex. `no-reply@quinch.sn`), jamais `example.com`.
5. `QUEUE_CONNECTION=redis` et le service `queue` du docker-compose démarré.
6. `php artisan quinch:preflight --as=production` doit afficher « Preflight OK » (l'entrypoint Docker
   le lance déjà : le conteneur refuse de démarrer si l'e-mail est mal configuré).

## 4. Domaine d'expédition : SPF, DKIM, DMARC

Sans ces trois enregistrements DNS, Gmail et les autres boîtes classent le code en spam, voire le
rejettent. Le fournisseur d'e-mails affiche les valeurs exactes à créer chez le gestionnaire DNS de
`quinch.sn` :

- **SPF** (TXT sur le domaine) : autorise le fournisseur à envoyer pour votre domaine.
- **DKIM** (TXT ou CNAME fournis par le fournisseur) : signe chaque message.
- **DMARC** (TXT sur `_dmarc.quinch.sn`) : commencer par `v=DMARC1; p=none; rua=mailto:dmarc@quinch.sn`,
  vérifier les rapports quelques semaines, puis passer à `p=quarantine`.

Attendre que le tableau de bord du fournisseur affiche le domaine comme « vérifié » avant de tester.

## 5. « Je ne reçois pas le code » : check-list

1. `php artisan quinch:mail-test adresse --queue` répond-il OK ? (sinon : réglages SMTP ou worker)
2. Worker actif ? `docker compose ps queue` puis `docker compose logs --tail=50 queue`.
3. Envois en échec : `php artisan queue:failed` (le code y est chiffré). Relancer : `php artisan queue:retry all`.
4. Journal : `storage/logs/laravel.log`, lignes « E-mail de code non envoyé » (adresse masquée).
5. Tableau de bord du fournisseur : message accepté, rejeté, ou signalé spam ?
6. Dossier courriers indésirables du destinataire ; domaine d'expédition non vérifié (§4).

## 6. Garde-fous déjà en place

- 60 s entre deux envois à la même adresse, 5 par heure et par adresse, plafond global horaire
  (`QUINCH_OTP_*`) : une adresse inconnue est limitée comme une adresse connue.
- Réponse identique que le compte existe ou non (pas d'énumération), même si la file est en panne.
- 5 essais de saisie par code, code à usage unique, sessions révoquées après réinitialisation.
- Le contenu du message (code) est chiffré dans Redis et dans `failed_jobs`.
