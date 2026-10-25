import '../../core/json/json_utils.dart';

/// Éditeur du service (`publisher` de `GET legal/info`). Tout champ non
/// renseigné côté serveur reste null : rien n'est inventé.
class LegalPublisher {
  const LegalPublisher({
    this.name,
    this.status,
    this.address,
    this.registration,
    this.director,
  });

  factory LegalPublisher.fromJson(Object? json) {
    final m = asMap(json);
    return LegalPublisher(
      name: asStringOrNull(m['name']),
      status: asStringOrNull(m['status']),
      address: asStringOrNull(m['address']),
      registration: asStringOrNull(m['registration']),
      director: asStringOrNull(m['director']),
    );
  }

  final String? name;
  final String? status;
  final String? address;
  final String? registration;
  final String? director;
}

/// Réponse de `GET legal/info` (route publique, voir `LegalController::info`).
/// Les textes juridiques eux-mêmes sont dans l'application ; le serveur ne
/// fournit que les informations propres à l'éditeur, les versions et les durées.
class LegalInfo {
  const LegalInfo({
    this.publisher = const LegalPublisher(),
    this.cdpReceipt,
    this.contactEmail,
    this.privacyEmail,
    this.hostingProvider,
    this.hostingLocation,
    this.termsVersion,
    this.privacyVersion,
    this.anonymizedContentDays,
    this.auditLogsDays,
  });

  factory LegalInfo.fromJson(Object? json) {
    final m = asMap(json);
    final hosting = asMap(m['hosting']);
    final versions = asMap(m['versions']);
    final retention = asMap(m['retention']);
    return LegalInfo(
      publisher: LegalPublisher.fromJson(m['publisher']),
      cdpReceipt: asStringOrNull(m['cdp_receipt']),
      contactEmail: asStringOrNull(m['contact_email']),
      privacyEmail: asStringOrNull(m['privacy_email']),
      hostingProvider: asStringOrNull(hosting['provider']),
      hostingLocation: asStringOrNull(hosting['location']),
      termsVersion: asStringOrNull(versions['terms']),
      privacyVersion: asStringOrNull(versions['privacy']),
      anonymizedContentDays: retention['anonymized_content_days'] == null
          ? null
          : asInt(retention['anonymized_content_days']),
      auditLogsDays: retention['audit_logs_days'] == null
          ? null
          : asInt(retention['audit_logs_days']),
    );
  }

  final LegalPublisher publisher;
  final String? cdpReceipt;
  final String? contactEmail;
  final String? privacyEmail;
  final String? hostingProvider;
  final String? hostingLocation;

  /// Versions des textes acceptées à l'inscription (réglées côté serveur).
  final String? termsVersion;
  final String? privacyVersion;

  /// Durées de conservation en jours.
  final int? anonymizedContentDays;
  final int? auditLogsDays;
}
