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
