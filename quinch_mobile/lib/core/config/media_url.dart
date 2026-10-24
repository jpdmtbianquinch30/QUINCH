/// Résout les URLs de médias renvoyées par l'API.
///
/// Vérifié dans le backend : images, posters, avatars et couvertures sont déjà
/// absolus (App\Support\MediaUrl). Les vidéos et miniatures du feed, de
/// l'Explorer et du détail sont RELATIVES au serveur, ex. `/api/v1/videos/{id}/stream`.
class MediaUrl {
  const MediaUrl(this.serverOrigin);

  /// Origine du serveur, sans `/api/v1`. Ex. https://api.quinch.sn
  final Uri serverOrigin;

  factory MediaUrl.fromApiBase(String apiBaseUrl) {
    final u = Uri.parse(apiBaseUrl);
    return MediaUrl(
      Uri(scheme: u.scheme, host: u.host, port: u.hasPort ? u.port : null),
    );
  }

  String? resolve(String? value) {
    if (value == null || value.isEmpty) return null;
    final parsed = Uri.tryParse(value);
    if (parsed == null) return null;
    if (parsed.hasScheme) {
      return (parsed.scheme == 'https' || parsed.scheme == 'http')
          ? value
          : null;
    }
    return serverOrigin.resolveUri(parsed).toString();
  }
}
