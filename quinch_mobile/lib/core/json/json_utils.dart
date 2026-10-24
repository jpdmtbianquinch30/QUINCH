/// Lecture JSON tolérante. Un champ absent ou d'un type inattendu donne
/// null ou la valeur par défaut indiquée : aucune valeur n'est inventée.
typedef Json = Map<String, dynamic>;

Json asMap(Object? v) => v is Map ? Json.from(v) : <String, dynamic>{};

Json? asMapOrNull(Object? v) => v is Map ? Json.from(v) : null;

List<Json> asMapList(Object? v) => v is List
    ? [
        for (final e in v)
          if (e is Map) Json.from(e),
      ]
    : <Json>[];

String? asStringOrNull(Object? v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

String asString(Object? v, [String fallback = '']) =>
    asStringOrNull(v) ?? fallback;

int asInt(Object? v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) {
    return int.tryParse(v) ?? double.tryParse(v)?.toInt() ?? fallback;
  }
  return fallback;
}

double asDouble(Object? v, [double fallback = 0]) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
}

bool asBool(Object? v, [bool fallback = false]) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.toLowerCase();
    if (s == 'true' || s == '1') return true;
    if (s == 'false' || s == '0') return false;
  }
  return fallback;
}

DateTime? asDate(Object? v) => v is String ? DateTime.tryParse(v) : null;

List<String> asStringList(Object? v) => v is List
    ? [
        for (final e in v)
          if (e != null) e.toString(),
      ]
    : <String>[];
