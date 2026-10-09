# Phase 5 — Conformité légale : ce qui est fait, ce qu'il vous reste à décider

> Je ne suis pas juriste. Les textes (conditions, confidentialité, mentions) sont un **projet sérieux et
> adapté à QUINCH**, mais ils doivent être **relus par un juriste sénégalais avant l'ouverture au public**.
> Chaque point marqué « décision » est un choix qui vous appartient.

## 1. Cadre sénégalais retenu (sources officielles à consulter)

- **Loi n° 2008-12 du 25 janvier 2008** sur la protection des données à caractère personnel, appliquée
  par la **CDP** (Commission de Protection des Données Personnelles), cdp.sn.
- La CDP exige une **déclaration** (récépissé) ou, selon le traitement, une **autorisation** avant de traiter
  des données personnelles ; les formulaires sont sur cdp.sn (« liste des formulaires »).
- Points que la CDP signale comme manquements fréquents : traitements non déclarés et **conservation sans
  limite de durée**. Le **transfert de données vers l'étranger** (serveurs hors du Sénégal) a sa propre procédure.
- À vérifier avec la CDP ou un juriste : le formulaire exact pour QUINCH, le régime du transfert vers le pays de
  vos serveurs, et les obligations en cas de violation de données.

## 2. Ce qui a été ajouté au projet

| Obligation | Ce qui est en place |
|---|---|
| Informer les personnes | Pages publiques `/legal/cgu`, `/legal/confidentialite`, `/legal/mentions-legales` ; liens à l'inscription, sous le bouton Google et dans les réglages |
| Identité de l'éditeur | Renseignée dans `backend/.env.docker` (`LEGAL_*`), servie par `GET /api/v1/legal/info` ; **la production refuse de démarrer si elle est vide** |
| Consentement | Case obligatoire à l'inscription ; pour Google, **fenêtre de consentement explicite** à la première connexion (un compte déjà existant se connecte directement, un nouveau compte n'est créé qu'après avoir coché la case). Date et version des textes mémorisées (`terms_accepted_at`, `terms_version`, `privacy_version`) |
| Droit d'accès / portabilité | « Exporter mes données » : export complet en JSON téléchargeable (profil, annonces, vidéos, transactions, conversations, avis, favoris, notifications, messages envoyés, etc.). **Correction d'un bug** : l'ancien export plantait (erreur 500) sur des relations inexistantes |
| Droit à l'effacement | La suppression du compte efface aussi localisation, coordonnées GPS, pièce d'identité (kyc), préférences, notifications, favoris, abonnements, photos de profil. Les annonces, vidéos, photos et messages sont **effacés définitivement après 30 jours** (tâche quotidienne `PurgeAnonymizedAccountData`) |
| Durées de conservation | Configurables (`LEGAL_ANONYMIZED_CONTENT_DAYS`, `LEGAL_AUDIT_LOGS_DAYS`), appliquées par des tâches planifiées, affichées dans la politique |
| Registre des traitements | `docs/conformite/REGISTRE_TRAITEMENTS.md` (base de votre déclaration CDP) |

## 3. Décisions qui vous appartiennent (à valider avec un juriste)

1. **Statut de l'éditeur.** Aujourd'hui : projet porté à titre individuel. Vous devriez **créer l'entité avant
   l'ouverture publique** : les comptes marchands Wave / Orange Money et la responsabilité (contrats,
   données personnelles) sont bien plus simples avec une entreprise immatriculée (NINEA, RCCM). À confirmer
   avec un conseil ou le guichet unique de création d'entreprise.
2. **Âge minimum.** Les conditions disent « réservé aux personnes majeures ». Rien dans l'application ne le
   vérifie : à décider (simple déclaration, ou date de naissance à l'inscription).
3. **Remboursement Premium.** Texte actuel : pas de remboursement d'une période entamée, sauf erreur de
   facturation ou paiement en double. À confirmer (et à aligner avec les règles Wave / Orange Money).
4. **Juridiction.** Texte actuel : droit sénégalais, tribunaux sénégalais. À confirmer.
5. **Délai de réponse aux demandes de droits.** Texte actuel : 30 jours maximum. C'est un engagement public.
6. **Messagerie.** Les messages envoyés sont effacés 30 jours après suppression du compte, ceux reçus restent
   visibles chez l'autre personne (qui y a droit). À valider.
7. **Données de paiement.** Les lignes de transactions sont gardées pour la comptabilité ; la durée exacte
   (souvent 10 ans en comptabilité OHADA) est à confirmer avec un expert-comptable.

## 4. Formalités auprès de la CDP (avant l'ouverture)

1. Compléter `REGISTRE_TRAITEMENTS.md` (déjà pré-rempli).
2. Retrouver sur cdp.sn le formulaire de déclaration adapté (traitement de données de comptes d'utilisateurs /
   plateforme en ligne) et la procédure de **transfert hors Sénégal** (hébergement Contabo, stockage objet/CDN).
3. Indiquer **le pays exact des serveurs** (`LEGAL_HOST_LOCATION`) : choisissez le centre de données avant de
   déclarer, car il figure dans la déclaration.
4. Une fois le récépissé reçu : `LEGAL_CDP_RECEIPT=<numéro>` dans `.env.docker` (affiché dans la politique).
5. Contrat avec chaque sous-traitant (hébergeur, e-mail, paiement) : vérifier leurs conditions de traitement des données.

## 5. Procédure : demande d'un utilisateur sur ses données

1. Vérifier l'identité : la demande doit venir de l'adresse e-mail du compte.
2. **Accès / portabilité** : l'utilisateur peut le faire seul (Réglages → Exporter mes données). Sinon, un
   administrateur lance l'export et l'envoie à l'adresse du compte.
3. **Suppression** : Réglages → Supprimer mon compte, ou demande par e-mail (suppression par l'administration).
4. **Rectification** : l'utilisateur modifie son profil ; sinon correction manuelle par un administrateur.
5. Répondre dans le délai annoncé (30 jours) et garder une trace de la demande et de la réponse.

## 6. Procédure : incident de sécurité (fuite de données)

1. **Contenir** : révoquer les jetons (`php artisan tinker` → `PersonalAccessToken::query()->delete()`), changer
   les secrets (voir `PHASE4_SECURITE.md`), isoler le serveur si nécessaire.
2. **Évaluer** : quelles données, combien de personnes, depuis quand (journaux d'audit, accès serveur).
3. **Notifier** : les personnes concernées si le risque est élevé, et la CDP (demandez à la CDP / au juriste le
   délai et le formulaire applicables).
4. **Corriger puis documenter** : cause, correction, date, personnes informées.

## 7. Avant l'ouverture publique : liste de contrôle

- [ ] Entité juridique créée, `LEGAL_PUBLISHER_*` renseignés
- [ ] Adresse `contact@quinch.sn` réellement créée et surveillée
- [ ] Centre de données choisi, `LEGAL_HOST_LOCATION` renseigné
- [ ] Déclaration CDP déposée (et transfert si nécessaire), récépissé renseigné
- [ ] Textes relus par un juriste ; `LEGAL_TERMS_VERSION` / `LEGAL_PRIVACY_VERSION` mis à jour si les textes changent
- [ ] Décisions du §3 prises et textes ajustés
- [ ] Test de bout en bout : inscription (case obligatoire) → export des données → suppression de compte
