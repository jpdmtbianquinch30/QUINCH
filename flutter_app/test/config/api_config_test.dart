import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quinch/config/api_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // ApiConfig.init() lit SharedPreferences en mode debug (voir
    // api_config.dart) : on simule un stockage vide pour que init()
    // fonctionne sans plateforme native réelle.
    SharedPreferences.setMockInitialValues({});
    await ApiConfig.init();
  });

  group('ApiConfig.resolveUrl', () {
    test('retourne une chaine vide telle quelle', () {
      expect(ApiConfig.resolveUrl(''), '');
    });

    test('laisse une URL http:// deja absolue inchangee', () {
      expect(
        ApiConfig.resolveUrl('http://example.com/img.png'),
        'http://example.com/img.png',
      );
    });

    test('laisse une URL https:// deja absolue inchangee', () {
      expect(
        ApiConfig.resolveUrl('https://example.com/img.png'),
        'https://example.com/img.png',
      );
    });

    test('prefixe un chemin commencant par / avec le serverUrl', () {
      final result = ApiConfig.resolveUrl('/storage/videos/x.mp4');
      expect(result, '${ApiConfig.serverUrl}/storage/videos/x.mp4');
      expect(result, isNot(contains('//storage'))); // pas de double slash
    });

    test('prefixe un chemin relatif (sans /) avec le serverUrl + /', () {
      final result = ApiConfig.resolveUrl('storage/videos/x.mp4');
      expect(result, '${ApiConfig.serverUrl}/storage/videos/x.mp4');
    });
  });

  group('ApiConfig.baseUrl / storageUrl', () {
    test('baseUrl ajoute /api/v1 au serverUrl', () {
      expect(ApiConfig.baseUrl, '${ApiConfig.serverUrl}/api/v1');
    });

    test('storageUrl ajoute /storage au serverUrl', () {
      expect(ApiConfig.storageUrl, '${ApiConfig.serverUrl}/storage');
    });
  });
}
