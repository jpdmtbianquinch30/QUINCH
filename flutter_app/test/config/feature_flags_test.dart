import 'package:flutter_test/flutter_test.dart';
import 'package:quinch/config/feature_flags.dart';

/// Verrouille les valeurs par défaut V1 des feature flags Flutter, qui
/// doivent rester synchronisées avec backend/config/quinch.php. Si ce test
/// casse après une modification volontaire, pensez à réactiver l'UI
/// correspondante (voir product_detail_screen.dart, seller_profile_screen.dart,
/// favorites_screen.dart, chat_screen.dart) en même temps que le flag.
void main() {
  group('FeatureFlags V1 (doivent rester desactivees)', () {
    test('negotiation est desactivee', () {
      expect(FeatureFlags.negotiation, isFalse);
    });

    test('follow est desactivee', () {
      expect(FeatureFlags.follow, isFalse);
    });

    test('reviews est desactivee', () {
      expect(FeatureFlags.reviews, isFalse);
    });

    test('badges est desactivee', () {
      expect(FeatureFlags.badges, isFalse);
    });

    test('sharing est desactivee', () {
      expect(FeatureFlags.sharing, isFalse);
    });

    test('chatAudio est desactivee', () {
      expect(FeatureFlags.chatAudio, isFalse);
    });

    test('chatFile est desactivee', () {
      expect(FeatureFlags.chatFile, isFalse);
    });

    test('favoritesCollections est desactivee', () {
      expect(FeatureFlags.favoritesCollections, isFalse);
    });
  });
}
