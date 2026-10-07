# Registre des traitements de données personnelles — QUINCH

Pré-rempli d'après le code (octobre 2026). À relire, compléter (`[à compléter]`) et utiliser pour la déclaration CDP.

Responsable du traitement : `[nom de l'éditeur — LEGAL_PUBLISHER_NAME]` — contact : `[LEGAL_PRIVACY_EMAIL]`.
Hébergement : Contabo, pays des serveurs : `[LEGAL_HOST_LOCATION]` (transfert hors Sénégal : à déclarer).

| # | Traitement | Finalité | Données | Fondement | Destinataires | Durée de conservation |
|---|---|---|---|---|---|---|
| 1 | Comptes utilisateurs | Créer et gérer le compte, authentifier | Nom, nom d'utilisateur, e-mail, mot de passe haché, photo, couverture, bio, ville, région, identifiant Google | Contrat | Hébergeur, e-mail | Durée du compte ; identité effacée à la suppression |
| 2 | Annonces et médias | Publier et diffuser les annonces | Vidéos, photos, titres, descriptions, prix, catégories | Contrat | Hébergeur, stockage objet/CDN, autres utilisateurs | Durée du compte ; effacement définitif 30 jours après suppression |
| 3 | Messagerie | Échanges acheteur/vendeur | Messages, pièces jointes | Contrat | Destinataires ; modération sur signalement | Durée du compte ; messages envoyés effacés 30 jours après suppression |
| 4 | Interactions | Favoris, « j'aime », abonnements, avis, négociations | Identifiants et contenus des interactions | Contrat | Autres utilisateurs (avis, compteurs) | Supprimés avec le compte |
| 5 | Paiements | Abonnement Premium, frais d'annonce | Montant, date, statut, référence Wave/Orange Money | Contrat, obligation légale | Wave, Orange Money | Durée comptable `[à confirmer]` |
| 6 | Sécurité et antifraude | Détecter abus, fraudes, connexions suspectes | Adresse IP, appareil, empreinte d'appareil, journaux d'actions | Intérêt légitime | Équipe habilitée | 180 jours (`LEGAL_AUDIT_LOGS_DAYS`) |
| 7 | Modération | Examiner signalements, sanctionner, traiter les contestations | Signalements, décisions, avertissements | Intérêt légitime | Équipe de modération | Journal d'administration conservé comme preuve `[durée à fixer]` |
| 8 | Statistiques d'usage | Améliorer l'application | Pages/annonces consultées, identifiant de session anonyme | Intérêt légitime | Équipe | `[à fixer — voir ci-dessous]` |
| 9 | E-mails et notifications | Codes, alertes de compte | E-mail, contenu des messages système | Contrat, consentement (notifications) | Prestataire d'envoi d'e-mails | Codes : quelques minutes |
| 10 | Vérification d'identité (kyc) | `[si activée]` | Données de vérification | Consentement | `[à compléter]` | Effacées à la suppression du compte |

## Points à traiter (conservation illimitée = manquement fréquent relevé par la CDP)

- **Statistiques d'usage (#8) et journal d'administration (#7)** : aucune durée n'est appliquée aujourd'hui.
  Fixez une durée (par exemple 12 à 24 mois pour les statistiques) puis ajoutez-la à la tâche
  `PurgeExpiredAdminData`. Dites-le-moi et je l'implémente.
- **Fichiers de messages** : leur effacement repose sur l'URL enregistrée dans les métadonnées ; à revérifier
  lors du passage au stockage objet (phase 6).
- **Sauvegardes** (phase 6) : une donnée supprimée subsiste dans les sauvegardes jusqu'à leur expiration ;
  prévoir une rotation courte (ex. 30 jours) et la mentionner dans la déclaration.
