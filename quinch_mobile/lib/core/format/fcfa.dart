/// Affichage des prix : QUINCH affiche les montants en FCFA.
/// Le serveur accepte XOF, EUR et USD à la création ; l'application n'envoie que XOF.
String formatFcfa(num amount) {
  final rounded = amount.round();
  final digits = rounded.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('\u00A0');
    buffer.write(digits[i]);
  }
  return '${rounded < 0 ? '-' : ''}$buffer\u00A0FCFA';
}

/// Affiche un prix selon sa devise. Une devise autre que XOF est affichée telle
/// que renvoyée par le serveur, sans conversion.
String formatPrice(num amount, String? currency) {
  if (currency == null || currency.isEmpty || currency == 'XOF') {
    return formatFcfa(amount);
  }
  return '${amount.round()}\u00A0$currency';
}
