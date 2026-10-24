/// Temps écoulé en français : « à l'instant », « il y a 5 min », « hier »…
/// `now` est injecté pour rester testable.
String timeAgoFr(DateTime then, {required DateTime now}) {
  final diff = now.difference(then);
  if (diff.isNegative || diff.inSeconds < 60) {
    return "à l'instant";
  }
  if (diff.inMinutes < 60) {
    return 'il y a ${diff.inMinutes} min';
  }
  if (diff.inHours < 24) {
    return 'il y a ${diff.inHours} h';
  }
  if (diff.inDays == 1) {
    return 'hier';
  }
  if (diff.inDays < 7) {
    return 'il y a ${diff.inDays} j';
  }
  return formatDateFr(then);
}

String formatDateFr(DateTime date) {
  final local = date.toLocal();
  final d = local.day.toString().padLeft(2, '0');
  final m = local.month.toString().padLeft(2, '0');
  return '$d/$m/${local.year}';
}

String formatDateTimeFr(DateTime date) {
  final local = date.toLocal();
  final h = local.hour.toString().padLeft(2, '0');
  final min = local.minute.toString().padLeft(2, '0');
  return '${formatDateFr(date)} à $h:$min';
}
