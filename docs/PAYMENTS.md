# Paiements QUINCH

## Périmètre

QUINCH encaisse directement pour ses propres fonctionnalités Premium et frais configurés de publication. QUINCH ne sert pas de portefeuille ou de caisse pour les transactions commerciales entre utilisateurs.

## Architecture

```text
Angular
  ↓
Laravel
  ↓
Gateway
  ↓
Wave / Orange Money
  ↓
Webhook signé
  ↓
Laravel
  ↓
Transaction atomique
  ↓
Premium / statut interne
```

## Wave

Variables :

```text
WAVE_BASE_URL
WAVE_API_KEY
WAVE_WEBHOOK_SECRET
```

Ne jamais mettre `WAVE_API_KEY` dans le frontend.

## Idempotence

Un même événement webhook peut être reçu plusieurs fois. Le traitement doit donc utiliser une clé d'idempotence/référence fournisseur et empêcher une seconde activation ou un second enregistrement financier.

## Commandes entre utilisateurs (désactivées par défaut : `QUINCH_FEATURE_PURCHASES=false`)

Les webhooks `POST /webhooks/wave` (client_reference = UUID de la transaction) et `POST /webhooks/orange-money`
appellent `App\Services\Payments\OrderPaymentConfirmer`, qui applique ces règles sous verrou de ligne :

| Événement | Effet |
|---|---|
| Succès, montant et devise corrects | Commande payée → `processing` ; notifications acheteur et vendeur |
| Succès, montant ou devise inattendu / absent | Commande **non** validée, `security_check = manual_review`, log critique |
| Succès rejoué | Aucun effet (idempotent) |
| Succès après annulation (réservation expirée) | Stock re-réservé si disponible, sinon commande `disputed` + `manual_review` + log « remboursement à faire » |
| Échec Wave | Compté seulement (le client peut réessayer pendant 30 min) ; la réservation expire via `ReleaseExpiredReservations` |
| Échec Orange Money (définitif) | Commande annulée, stock restitué **une seule fois** |
| Échec après paiement | Ignoré : un paiement réussi n'est jamais défait |

Montant attendu : `amount + transaction_fee` en XOF. Les champs du webhook Orange Money (`order_id`, `status`, `amount`,
`currency`, `txnid`) sont à confirmer avec la documentation Sonatel.

Statuts de commande : `delivered` n'est possible que depuis `processing`/`shipped` (une seule fois) ; l'annulation par le
vendeur restitue le stock (et place une commande déjà payée en revue pour remboursement) ; l'acheteur ne peut annuler
qu'une commande non payée.

Avant d'activer les achats : brancher la réconciliation des commandes (`ReconcileWavePayments` ne couvre aujourd'hui que
Premium et frais de publication) et un processus de remboursement.

## Réconciliation

Le job `ReconcileWavePayments` permet de retrouver les paiements restés en attente lorsque le webhook n'a pas été reçu ou n'a pas pu être traité.

## Remboursements

Avant d'activer un remboursement en production :

- définir qui peut le déclencher ;
- journaliser l'action ;
- vérifier le statut fournisseur ;
- enregistrer la référence du remboursement ;
- empêcher les doublons ;
- mettre à jour la transaction interne.

## Orange Money

Ne l'activer que lorsque le compte marchand/API de production est effectivement obtenu et que les secrets sont configurés.

## Règle critique

Le frontend ne doit jamais envoyer :

```text
"payment_success=true"
```

comme preuve de paiement. La source de vérité est le backend et le fournisseur de paiement.
