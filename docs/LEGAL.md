# Conformité et cadre légal QUINCH

> Ce document décrit ce qui est **implémenté** et ce qui reste à faire. Il ne remplace pas un conseil
> juridique : les textes publics doivent être relus par un juriste sénégalais avant l'ouverture au public.

Détail complet, décisions à prendre et liste de contrôle : [`conformite/CONFORMITE_LEGALE.md`](conformite/CONFORMITE_LEGALE.md).
Registre des traitements (base de la déclaration CDP) : [`conformite/REGISTRE_TRAITEMENTS.md`](conformite/REGISTRE_TRAITEMENTS.md).

## Statut actuel

QUINCH est un projet porté à titre individuel ; la société n'est pas encore constituée. Hébergement prévu :
VPS Contabo, déploiement Dokploy, stockage objet + CDN pour les médias. Contact légal envisagé :
`contact@quinch.sn` (adresse à créer).

Recommandation : constituer l'entité **avant** l'ouverture publique (comptes marchands Wave / Orange Money,
responsabilité, déclaration CDP au nom de l'éditeur).

## Cadre retenu

- Loi sénégalaise n° 2008-12 du 25 janvier 2008 sur la protection des données à caractère personnel.
- Autorité : CDP (Commission de Protection des Données Personnelles), cdp.sn : déclaration ou autorisation
  préalable, procédure propre pour le transfert de données hors du Sénégal.

## Ce qui est en place

| Sujet | Implémentation |
|---|---|
| Pages publiques | `/legal/cgu`, `/legal/confidentialite`, `/legal/mentions-legales` (Angular, `pages/legal`). Les informations de l'éditeur viennent de `GET /api/v1/legal/info` |
| Informations de l'éditeur | Variables `LEGAL_*` (`backend/.env.docker`) ; `quinch:preflight` bloque la production si elles sont vides |
| Consentement (e-mail) | Case obligatoire à l'inscription (`accept_terms`) |
| Consentement (Google) | **Étape explicite** : un compte déjà existant se connecte directement ; pour un nouveau compte, l'API répond 422 `terms_required` et le frontend affiche une fenêtre avec la case à cocher avant de créer le compte |
| Preuve du consentement | `users.terms_accepted_at`, `terms_version`, `privacy_version` (versions réglées par `LEGAL_TERMS_VERSION` / `LEGAL_PRIVACY_VERSION`) |
| Droit d'accès / portabilité | `GET /users/export-data` : JSON téléchargeable complet (`UserDataExporter`) ; 5 demandes par heure |
| Droit à l'effacement | `POST /auth/delete-account` : identité, localisation, GPS, kyc, préférences, notifications, favoris, abonnements et photos de profil effacés immédiatement (`SanctionService::anonymize`) |
| Effacement différé | Tâche quotidienne `PurgeAnonymizedAccountData` : annonces (textes et fichiers), vidéos et messages effacés après `LEGAL_ANONYMIZED_CONTENT_DAYS` jours (30 par défaut) |
| Conservation des journaux | `LEGAL_AUDIT_LOGS_DAYS` (180 par défaut), tâche `PurgeExpiredAdminData` |

## Paiements

Les conditions d'utilisation expliquent que QUINCH facture ses propres fonctions (Premium, frais de publication)
et **ne gère pas le règlement des ventes entre utilisateurs**. Si les achats entre utilisateurs étaient un jour
activés (`QUINCH_FEATURE_PURCHASES`), les conditions devraient être complétées avant la mise en service.

## Reste à faire avant l'ouverture publique

- [ ] Constituer l'entité, renseigner `LEGAL_PUBLISHER_*`
- [ ] Créer et surveiller `contact@quinch.sn`
- [ ] Choisir le centre de données, renseigner `LEGAL_HOST_NAME` / `LEGAL_HOST_LOCATION`
- [ ] Déposer la déclaration CDP (et la demande de transfert hors Sénégal), renseigner `LEGAL_CDP_RECEIPT`
- [ ] Relecture des textes par un juriste ; trancher âge minimum, remboursement Premium, juridiction, délai de réponse aux demandes de droits
- [ ] Fixer une durée de conservation pour les statistiques d'usage et le journal d'administration
- [ ] Test de bout en bout : inscription, première connexion Google (consentement), export, suppression de compte

## Contenu utilisateur

Signalement, modération, retrait, contestation (appel) et sanctions existent déjà ; les règles de publication sont
résumées dans les conditions d'utilisation.
