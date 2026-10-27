import '../../core/format/fcfa.dart';
import '../../core/format/time_ago.dart';
import '../../data/models/chat.dart';

/// Heure d'un message dans une conversation : « 14:05 » aujourd'hui, sinon la date.
String formatMessageTime(DateTime? date, {required DateTime now}) {
  if (date == null) {
    return '';
  }
  final local = date.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  if (day == today) {
    return '$hh:$mm';
  }
  if (today.difference(day).inDays == 1) {
    return 'Hier $hh:$mm';
  }
  return formatDateFr(local);
}

/// Date courte pour la boîte de réception : heure, « Hier » ou date.
String formatInboxTime(DateTime? date, {required DateTime now}) {
  if (date == null) {
    return '';
  }
  final local = date.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  if (day == today) {
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
  if (today.difference(day).inDays == 1) {
    return 'Hier';
  }
  return formatDateFr(local);
}

const unsupportedMessageText =
    "Ce message n'est pas pris en charge dans cette version de l'application.";

/// Texte d'aperçu d'un message (boîte de réception) selon son type.
String messagePreview(ChatMessage? message) {
  if (message == null) {
    return 'Aucun message';
  }
  switch (message.type) {
    case ChatMessageType.text:
    case ChatMessageType.productTag:
      return message.body;
    case ChatMessageType.image:
      return 'Photo';
    case ChatMessageType.video:
      return 'Vidéo';
    case ChatMessageType.file:
      return 'Fichier';
    default:
      return message.body.isEmpty ? unsupportedMessageText : message.body;
  }
}

/// « Prix » d'une annonce liée, ou null s'il est inconnu.
String? formatLinkedPrice(double? price) =>
    price == null ? null : formatFcfa(price);

/// Textes des confirmations de suppression : le serveur supprime pour TOUS les
/// participants, il faut le dire avant que l'utilisateur confirme.
const deleteMessageWarning =
    "Ce message sera supprimé pour vous et pour l'autre personne. Cette action "
    'est définitive.';

const deleteConversationWarning =
    "Tous les messages de cette conversation seront supprimés pour vous et "
    "pour l'autre personne. Cette action est définitive.";

String deleteConversationsWarning(int count) {
  final target = count > 1 ? 'ces $count conversations' : 'cette conversation';
  return 'Les messages de $target seront supprimés pour vous et pour les '
      'autres participants. Cette action est définitive.';
}
