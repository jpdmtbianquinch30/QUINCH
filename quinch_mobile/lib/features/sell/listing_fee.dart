import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/fcfa.dart';
import '../../core/platform/url_opener.dart';
import '../../data/models/premium.dart';
import '../../data/models/product.dart';

/// Frais de publication d'une annonce avec vidéo (compte gratuit, hors bêta).
///
/// Le serveur est seul juge : il garde l'annonce en brouillon et renvoie une
/// adresse de paiement. Ni cette boîte de dialogue ni le retour du navigateur ne
/// prouvent qu'un paiement a réussi.
///
/// Renvoie true si l'utilisateur choisit d'ouvrir la page de paiement.
Future<bool> askListingFeePayment(BuildContext context, {int? fee}) async {
  final amount = fee == null || fee <= 0
      ? 'Des frais de publication sont dus'
      : 'Frais de publication : ${formatFcfa(fee)}';
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Frais de publication vidéo'),
      content: Text(
        '$amount. Vous allez être redirigé vers une page de paiement '
        'sécurisée, hors de QUINCH. Votre annonce reste en brouillon tant que '
        "le serveur n'a pas confirmé le paiement.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Plus tard'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Payer'),
        ),
      ],
    ),
  );
  return result ?? false;
}

const listingFeePendingMessage =
    "Paiement en cours de traitement. L'annonce sera publiée dès que le "
    'serveur aura confirmé le paiement : actualisez « Mes annonces ».';

const listingFeeLinkUnavailableMessage =
    'Le lien de paiement est indisponible. Votre annonce reste en brouillon.';

const listingFeeOpenFailedMessage =
    "Impossible d'ouvrir la page de paiement. Votre annonce reste en brouillon.";

const listingFeeLaterMessage =
    'Annonce enregistrée en brouillon. Payez les frais pour la publier.';

/// Parcours complet quand le serveur demande des frais de publication :
/// explication, puis ouverture de la page de paiement si l'utilisateur accepte.
///
/// Renvoie le message à afficher ensuite, ou null si l'écran a disparu entre-temps.
/// L'annonce reste en brouillon : seul le serveur confirme un paiement.
Future<String?> runListingFeeFlow(
  BuildContext context,
  WidgetRef ref,
  ProductSaveResult result,
) async {
  final pay = await askListingFeePayment(context, fee: result.fee);
  if (!context.mounted) {
    return null;
  }
  if (!pay) {
    return listingFeeLaterMessage;
  }
  final start = PaymentStart.tryFromJson(<String, dynamic>{
    'payment_url': result.paymentUrl,
  });
  if (start == null) {
    return listingFeeLinkUnavailableMessage;
  }
  final opened = await ref.read(urlOpenerProvider)(start.paymentUrl);
  return opened ? listingFeePendingMessage : listingFeeOpenFailedMessage;
}
