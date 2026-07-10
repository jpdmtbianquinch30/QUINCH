import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quinch/config/api_config.dart';
import 'package:quinch/models/product.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiConfig.init();
  });

  group('Product.fromJson - champs minimaux', () {
    test('un JSON quasi vide ne plante pas et pose des defauts surs', () {
      final product = Product.fromJson({});

      expect(product.id, '');
      expect(product.title, '');
      expect(product.type, 'product');
      expect(product.price, 0.0);
      expect(product.currency, 'XOF');
      expect(product.status, 'active');
      expect(product.isLiked, isFalse);
      expect(product.isSaved, isFalse);
      expect(product.video, isNull);
      expect(product.images, isNull);
      expect(product.category, isNull);
      expect(product.seller, isNull);
    });

    test('id numerique (int) est bien converti en String', () {
      final product = Product.fromJson({'id': 12345});
      expect(product.id, '12345');
    });
  });

  group('Product.fromJson - price', () {
    test('price entier (int) est accepte', () {
      final product = Product.fromJson({'price': 15000});
      expect(product.price, 15000.0);
    });

    test('price decimal (double) est accepte', () {
      final product = Product.fromJson({'price': 15000.5});
      expect(product.price, 15000.5);
    });
  });

  group('Product.fromJson - images', () {
    test('images en liste de strings est bien parsee', () {
      final product = Product.fromJson({
        'images': ['a.jpg', 'b.jpg'],
      });
      expect(product.images, ['a.jpg', 'b.jpg']);
    });

    test('images contenant des elements non-string (ex: null) ne plante pas', () {
      final product = Product.fromJson({
        'images': ['a.jpg', null],
      });
      expect(product.images, isNotNull);
      expect(product.images!.length, 2);
    });

    test('images en chaine (deja serialisee) ne plante pas: null en sortie', () {
      final product = Product.fromJson({'images': '["a.jpg"]'});
      expect(product.images, isNull);
    });

    test('images absent -> null', () {
      final product = Product.fromJson({});
      expect(product.images, isNull);
    });
  });

  group('Product.fromJson - seller / user fallback', () {
    test('utilise "seller" en priorite si present', () {
      final product = Product.fromJson({
        'seller': {'id': 's1', 'full_name': 'Vendeur A'},
        'user': {'id': 'u1', 'full_name': 'User B'},
      });
      expect(product.seller?.id, 's1');
    });

    test('utilise "user" si "seller" est absent', () {
      final product = Product.fromJson({
        'user': {'id': 'u1', 'full_name': 'User B'},
      });
      expect(product.seller?.id, 'u1');
    });
  });

  group('Product.fromJson - video', () {
    test('video malformee (pas une Map) ne plante pas -> null', () {
      final product = Product.fromJson({'video': 'not-a-map'});
      expect(product.video, isNull);
    });

    test('video valide est bien parsee', () {
      final product = Product.fromJson({
        'video': {'id': 'v1', 'url': '/videos/v1.mp4'},
      });
      expect(product.video, isNotNull);
      expect(product.video!.id, 'v1');
    });
  });

  group('Product - displayPrice', () {
    test('produit avec prix affiche "X F CFA"', () {
      final product = Product.fromJson({'type': 'product', 'price': 15000});
      expect(product.displayPrice, '15000 F CFA');
    });

    test('service avec prix a 0 affiche "Sur devis"', () {
      final product = Product.fromJson({'type': 'service', 'price': 0});
      expect(product.displayPrice, 'Sur devis');
    });

    test('produit avec prix a 0 affiche quand meme le montant (pas "Sur devis")', () {
      final product = Product.fromJson({'type': 'product', 'price': 0});
      expect(product.displayPrice, '0 F CFA');
    });
  });

  group('Product - isInStock', () {
    test('stock null -> pas en stock', () {
      final product = Product.fromJson({});
      expect(product.isInStock, isFalse);
    });

    test('stock a 0 -> pas en stock', () {
      final product = Product.fromJson({'stock_quantity': 0});
      expect(product.isInStock, isFalse);
    });

    test('stock positif -> en stock', () {
      final product = Product.fromJson({'stock_quantity': 3});
      expect(product.isInStock, isTrue);
    });
  });

  group('Product - hasVideo / mediaUrl', () {
    test('pas de video -> hasVideo false', () {
      final product = Product.fromJson({});
      expect(product.hasVideo, isFalse);
    });

    test('video avec url -> hasVideo true', () {
      final product = Product.fromJson({
        'video': {'id': 'v1', 'url': '/videos/v1.mp4'},
      });
      expect(product.hasVideo, isTrue);
    });

    test('mediaUrl utilise poster_full_url en priorite', () {
      final product = Product.fromJson({
        'poster_full_url': 'https://cdn.example.com/poster.jpg',
        'poster_url': '/storage/poster2.jpg',
      });
      expect(product.mediaUrl, 'https://cdn.example.com/poster.jpg');
    });

    test('mediaUrl retombe sur images[0] si rien d\'autre disponible', () {
      final product = Product.fromJson({
        'images': ['first.jpg', 'second.jpg'],
      });
      expect(product.mediaUrl, ApiConfig.resolveUrl('first.jpg'));
    });

    test('mediaUrl vide si aucune source disponible', () {
      final product = Product.fromJson({});
      expect(product.mediaUrl, '');
    });
  });
}
