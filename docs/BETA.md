# Version bêta

Mode de fonctionnement de QUINCH pendant la bêta fermée : paiements coupés, Premium offert aux premiers inscrits,
comptes de l'équipe, et ce qu'il faut vérifier avant d'ouvrir.

## 1. Interrupteurs

| Variable | Valeur bêta | Effet |
|---|---|---|
| `QUINCH_BETA` | `true` | Publication avec vidéo gratuite pour tous ; les paiements Premium sont désactivés. |
| `QUINCH_PREMIUM_PAYMENTS` | `false` | Sans effet si `QUINCH_BETA=true` (les paiements Premium sont alors toujours coupés). |
| `QUINCH_PREMIUM_OFFER_SLOTS` | `100` | Nombre de places de l'offre Premium offert. |
| `QUINCH_PREMIUM_OFFER_DAYS` | `90` | Durée du Premium offert, en jours. |
| `QUINCH_LISTING_FEE_WITH_VIDEO` | `0` ou `150` | Ignoré en bêta (le frais annoncé au front vaut 0). |

`GET /api/v1/public-config` expose `beta`, `listing_fee_with_video`, `premium_offer_slots` et `premium_payments` :
le front s'appuie dessus pour afficher les messages bêta.

Messages vus par les utilisateurs :

- clic sur un abonnement (2 000 ou 20 000 F) : « Le mode de paiement n'est pas actif actuellement pour la version bêta. »
  (réponse API : `error: premium_coming_soon`) ;
- publication avec vidéo : message bêta de test, sans demande de paiement.

## 2. Offre « Premium offert aux 100 premiers »

Parcours utilisateur : page **Premium** → bouton **Postuler**.

| Étape | Détail |
|---|---|
| Voir l'offre | `GET /premium/offer` → `slots_total`, `slots_left`, `days`, `my_status` (`null`, `pending`, `granted`, `rejected`). |
| Postuler | `POST /premium/offer/apply` → `201` et `my_status: pending`. Déjà candidat : le statut existant est renvoyé. Déjà Premium ou plus de places : `422`. |
| Condition | **E-mail confirmé** (middleware `email.verified`). Sinon `403` avec `error: email_not_verified`. |
| Avertir l'équipe | À chaque candidature, les comptes qui ont la permission `premium.manage` (admin, super admin) reçoivent une notification vers `/admin/team`. Un échec d'envoi n'empêche pas l'enregistrement. |
| Décider | Admin → **Équipe & Premium** → onglet **Premium** → *Premium offert* : accorder ou refuser (`/admin/premium-offer`, `/{application}/grant`, `/{application}/reject`). |
| Accorder | Crée un abonnement gratuit (`payment_method=admin_grant`, montant 0) et ajoute `QUINCH_PREMIUM_OFFER_DAYS` jours. Verrou en base : deux admins ne peuvent pas dépasser le plafond. |

`email.verified` protège aussi `transactions/initiate` et `premium/subscribe`.

## 3. Comptes de l'équipe

- **Créer le premier super admin** (seul moyen, volontairement hors HTTP) :
  1. s'inscrire normalement avec un mot de passe d'au moins 14 caractères ;
  2. `docker compose exec app php artisan quinch:set-role <email> super_admin` (sessions révoquées, action journalisée en « critical »).
- **Nom d'utilisateur officiel** : tout pseudo contenant `quinch` est réservé aux utilisateurs normaux. Pour un compte
  officiel, s'inscrire avec un pseudo neutre puis, dans `php artisan tinker` :
  `App\Models\User::where('email','…')->update(['username'=>'quinchofficielsn']);`
- **Compte de démonstration** : `DatabaseSeeder` crée `admin@quinch.sn` avec un mot de passe trivial, uniquement en
  `local` et `testing`. Ne jamais l'exécuter sur un serveur. Sur une base locale : `quinch:set-role admin@quinch.sn user`,
  puis supprimer le compte depuis l'admin (un super admin ne peut pas en supprimer un autre).
- **Mots de passe** : changement par un membre de l'équipe : 14 caractères minimum ; création et réinitialisation d'un
  compte d'équipe : 12 caractères minimum. Utilisateurs normaux : règle inchangée (8 à 72, majuscule, minuscule, chiffre).
- **Super admin sur son propre compte** : peut s'attribuer des badges et régler sa confiance (boutons visibles sur son
  profil dans l'admin). Les autres rôles ne peuvent agir sur eux-mêmes ni pour les badges ni pour la confiance.
- **Confiance de l'équipe** : le recalcul quotidien et le recalcul à la sauvegarde du profil ne touchent pas les comptes
  d'équipe ; leur valeur reste celle que le super admin a choisie.
- **Boîte e-mail** : l'adresse d'un super admin reçoit les codes « mot de passe oublié ». Activer la validation en deux
  étapes sur cette boîte.

## 4. Pièges Docker rencontrés

- Le code est **copié dans l'image** : après chaque changement, reconstruire
  `docker compose up -d --build app queue queue_videos scheduler`, puis `php artisan migrate --force`.
- Avec Docker, `QUEUE_CONNECTION=redis` (les workers lisent Redis). `database` ou un worker arrêté : notifications à tous et
  e-mails restent en attente.
- Angular en développement doit passer par le backend Docker :
  `ng serve --proxy-config proxy.docker.conf.json` (cible `127.0.0.1:8080`). Le fichier `proxy.conf.json` vise `:8000`
  (`php artisan serve`) et ne partage ni file d'attente ni stockage avec Docker.
- Les vidéos téléversées par un serveur et traitées par un autre (stockage différent) échouent avec « Fichier vidéo
  introuvable ». Tous les services partagent le volume `storage_data`.

## 5. Avant d'ouvrir la bêta

- [ ] `php artisan test` au vert, `composer audit` et `npm audit --omit=dev --audit-level=high` propres.
- [ ] `ng build --configuration production` sans erreur.
- [ ] `docker compose exec app php artisan quinch:health --deep` : tout « ok », aucun job en échec.
- [ ] `quinch:preflight` sans erreur avec le vrai `backend/.env.docker` de production (`APP_ENV=production`).
- [ ] Mentions légales renseignées (`LEGAL_*`), mot de passe de base d'au moins 16 caractères aléatoires.
- [ ] Domaine, DNS, HTTPS (Caddy) ; `environment.prod.ts` à jour avec l'adresse réelle de l'API.
- [ ] Origines autorisées de la clé Google mises à jour avec le domaine.
- [ ] E-mails : fournisseur transactionnel et domaine (voir `docs/EMAIL.md`) ; `quinch:mail-test` reçu.
- [ ] Sauvegarde puis **restauration réelle** testées sur le serveur (`docs/BACKUPS.md`).
- [ ] `scripts/staging-smoke-test.sh` contre le serveur.
- [ ] Super admin créé, `admin@quinch.sn` absent (`quinch:set-role` puis liste des rôles dans `tinker`).
- [ ] Parcours manuel : inscription + e-mail de confirmation, publication vidéo gratuite, clic Premium, candidature
      (notification admin), message à tous.

Wave : le contrôle de démarrage de production refuse `wave` sans `WAVE_API_KEY` ni `WAVE_WEBHOOK_SECRET`. Pour une bêta sans
paiement, soit fournir les clés, soit laisser `QUINCH_PAYMENT_METHODS` vide (comportement à vérifier au premier démarrage).

## 6. Limites connues

- Pas de double authentification (2FA) pour l'équipe : à ajouter avant une ouverture large.
- Pas de tests unitaires côté Angular (`ng test` exécute 0 test) : le parcours manuel est la seule vérification de l'interface.
- Le style PHP (`pint --test`) signale des écarts ; aucun n'est un défaut fonctionnel, la CI ne le vérifie pas.
- Le recalcul quotidien de la confiance remplace les ajustements manuels faits sur les utilisateurs normaux.

## 7. Sortir de la bêta

1. `QUINCH_BETA=false`, `QUINCH_PREMIUM_PAYMENTS=true`.
2. Clés Wave (et secret de webhook) renseignées, `QUINCH_PAYMENT_METHODS=wave`.
3. `QUINCH_LISTING_FEE_WITH_VIDEO=150`.
4. Prévenir les utilisateurs (message à tous) : les paiements sont actifs, l'offre Premium offert est terminée.
