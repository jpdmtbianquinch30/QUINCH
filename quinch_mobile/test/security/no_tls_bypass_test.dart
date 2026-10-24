import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Garde-fou : aucune contournement TLS, aucun journal de requêtes, aucun print.
/// Lit le code source (hors commentaires) ; échoue si un motif interdit apparaît.
void main() {
  test('le code de lib/ ne contourne pas TLS et ne journalise pas', () {
    const forbidden = <String>[
      'badCertificateCallback',
      'HttpOverrides',
      'LogInterceptor',
      'allowBadCertificates',
      'onBadCertificate',
      'print(',
      'debugPrint(',
    ];
    final offenders = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    expect(files, isNotEmpty);
    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) {
          continue;
        }
        for (final token in forbidden) {
          if (line.contains(token)) {
            offenders.add('${file.path}:${i + 1} -> $token');
          }
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
