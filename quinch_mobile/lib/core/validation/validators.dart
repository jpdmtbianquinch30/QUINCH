/// Contrôles de saisie côté application : simple confort pour l'utilisateur.
/// Le serveur reste la seule autorité ; ses messages d'erreur priment.
abstract final class Validators {
  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final RegExp _username = RegExp(r'^[a-zA-Z0-9_]{3,30}$');

  static String? email(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) {
      return 'Saisissez votre adresse email.';
    }
    if (v.length > 255 || !_email.hasMatch(v)) {
      return 'Adresse email invalide.';
    }
    return null;
  }

  static String? fullName(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) {
      return 'Saisissez votre nom complet.';
    }
    if (v.length > 100) {
      return '100 caractères maximum.';
    }
    return null;
  }

  static String? username(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) {
      return "Choisissez un nom d'utilisateur.";
    }
    if (!_username.hasMatch(v)) {
      return 'Lettres, chiffres et _ uniquement (3 à 30 caractères).';
    }
    return null;
  }

  /// Connexion : on ne rejoue pas les règles de création de mot de passe.
  static String? passwordPresent(String? value) {
    if (value == null || value.isEmpty) {
      return 'Saisissez votre mot de passe.';
    }
    return null;
  }

  /// Création / réinitialisation : 8 à 72 caractères, une minuscule, une
  /// majuscule, un chiffre (règle du backend).
  static String? newPassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) {
      return 'Choisissez un mot de passe.';
    }
    if (v.length < 8) {
      return '8 caractères minimum.';
    }
    if (v.length > 72) {
      return '72 caractères maximum.';
    }
    final complete =
        RegExp(r'[a-z]').hasMatch(v) &&
        RegExp(r'[A-Z]').hasMatch(v) &&
        RegExp(r'\d').hasMatch(v);
    if (!complete) {
      return 'Une minuscule, une majuscule et un chiffre sont requis.';
    }
    return null;
  }

  static String? Function(String?) confirmation(String Function() original) {
    return (value) {
      if (value == null || value.isEmpty) {
        return 'Confirmez le mot de passe.';
      }
      if (value != original()) {
        return 'Les mots de passe ne correspondent pas.';
      }
      return null;
    };
  }

  static String? otp(String? value) {
    final v = (value ?? '').trim();
    if (v.length != 6) {
      return 'Le code contient 6 caractères.';
    }
    return null;
  }

  static String? bio(String? value) {
    if ((value ?? '').length > 500) {
      return '500 caractères maximum.';
    }
    return null;
  }

  /// Champ facultatif : vide accepté, sinon adresse http(s) valide.
  static String? websiteOptional(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(v);
    final ok =
        uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
    return ok && v.length <= 255
        ? null
        : "Saisissez une adresse complète (https://…).";
  }

  static String? maxLength100(String? value) {
    if ((value ?? '').trim().length > 100) {
      return '100 caractères maximum.';
    }
    return null;
  }

  /// Numéro sénégalais saisi sans l'indicatif : 9 chiffres. Vide accepté.
  static String? senegalPhoneDigitsOptional(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) {
      return null;
    }
    return RegExp(r'^[0-9]{9}$').hasMatch(v)
        ? null
        : 'Saisissez les 9 chiffres du numéro.';
  }

  static String? required(String? value, String message) {
    return (value ?? '').trim().isEmpty ? message : null;
  }

  static String? description2000(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) {
      return 'Décrivez le problème.';
    }
    if (v.length > 2000) {
      return '2000 caractères maximum.';
    }
    return null;
  }
}
