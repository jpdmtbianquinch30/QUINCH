import 'package:flutter_test/flutter_test.dart';
import 'package:quinch_mobile/core/validation/validators.dart';

void main() {
  group('email', () {
    test('valide', () {
      expect(Validators.email('awa@example.com'), isNull);
      expect(Validators.email('  awa@example.sn  '), isNull);
    });
    test('invalide ou vide', () {
      expect(Validators.email(null), isNotNull);
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('awa'), isNotNull);
      expect(Validators.email('awa@'), isNotNull);
      expect(Validators.email('a b@c.sn'), isNotNull);
    });
  });

  group('nom d\'utilisateur', () {
    test('valide', () {
      expect(Validators.username('awa_diop1'), isNull);
      expect(Validators.username('abc'), isNull);
    });
    test('invalide', () {
      expect(Validators.username(''), isNotNull);
      expect(Validators.username('ab'), isNotNull);
      expect(Validators.username('awa diop'), isNotNull);
      expect(Validators.username('awa-diop'), isNotNull);
      expect(Validators.username('a' * 31), isNotNull);
    });
  });

  group('nom complet', () {
    test('limites', () {
      expect(Validators.fullName('Awa Diop'), isNull);
      expect(Validators.fullName('   '), isNotNull);
      expect(Validators.fullName('a' * 101), isNotNull);
    });
  });

  group('mot de passe', () {
    test('règles du backend', () {
      expect(Validators.newPassword('Abcdef12'), isNull);
      expect(Validators.newPassword('Abc12'), isNotNull); // trop court
      expect(Validators.newPassword('abcdefg1'), isNotNull); // pas de majuscule
      expect(Validators.newPassword('ABCDEFG1'), isNotNull); // pas de minuscule
      expect(Validators.newPassword('Abcdefgh'), isNotNull); // pas de chiffre
      expect(
        Validators.newPassword('Aa1${'x' * 70}'),
        isNotNull,
      ); // 73 caractères
      expect(Validators.newPassword(''), isNotNull);
    });

    test('connexion : seule la présence est exigée', () {
      expect(Validators.passwordPresent('x'), isNull);
      expect(Validators.passwordPresent(''), isNotNull);
      expect(Validators.passwordPresent(null), isNotNull);
    });

    test('confirmation', () {
      var original = 'Abcdef12';
      final validate = Validators.confirmation(() => original);
      expect(validate('Abcdef12'), isNull);
      expect(validate('autre'), isNotNull);
      expect(validate(''), isNotNull);
      original = 'Nouveau123';
      expect(validate('Abcdef12'), isNotNull);
    });
  });

  test('code de réinitialisation', () {
    expect(Validators.otp('123456'), isNull);
    expect(Validators.otp(' 123456 '), isNull);
    expect(Validators.otp('12345'), isNotNull);
    expect(Validators.otp(null), isNotNull);
  });
}
