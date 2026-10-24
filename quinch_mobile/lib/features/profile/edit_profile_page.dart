import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_error.dart';
import '../../core/session/session_controller.dart';
import '../../core/validation/validators.dart';
import '../../data/models/user.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/product_widgets.dart';
import 'profile_providers.dart';

class EditProfilePage extends ConsumerWidget {
  const EditProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Modifier mon profil')),
      body: profile.when(
        loading: () => const Center(
          child: CircularProgressIndicator(semanticsLabel: 'Chargement'),
        ),
        error: (error, stackTrace) => ErrorRetry.fromError(
          error,
          onRetry: () => ref.invalidate(myProfileProvider),
        ),
        data: (user) => _EditForm(user: user),
      ),
    );
  }
}

class _EditForm extends ConsumerStatefulWidget {
  const _EditForm({required this.user});

  final AppUser user;

  @override
  ConsumerState<_EditForm> createState() => _EditFormState();
}

class _EditFormState extends ConsumerState<_EditForm> {
  final _profileKey = GlobalKey<FormState>();
  final _phoneKey = GlobalKey<FormState>();
  late final TextEditingController _fullName;
  late final TextEditingController _username;
  late final TextEditingController _email;
  late final TextEditingController _bio;
  late final TextEditingController _website;
  late final TextEditingController _city;
  late final TextEditingController _region;
  late final TextEditingController _phone;
  final _password = TextEditingController();

  late AppUser _user;
  bool _saving = false;
  bool _savingPhone = false;
  String? _error;
  String? _phoneError;
  final Map<String, String> _serverErrors = <String, String>{};

  static const _prefix = '+221';

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _fullName = TextEditingController(text: _user.fullName);
    _username = TextEditingController(text: _user.username);
    _email = TextEditingController(text: _user.email);
    _bio = TextEditingController(text: _user.bio ?? '');
    _website = TextEditingController(text: _user.website ?? '');
    _city = TextEditingController(text: _user.city ?? '');
    _region = TextEditingController(text: _user.region ?? '');
    final phone = _user.phoneNumber;
    _phone = TextEditingController(
      text: (phone != null && phone.startsWith(_prefix))
          ? phone.substring(_prefix.length)
          : '',
    );
    _email.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [
      _fullName,
      _username,
      _email,
      _bio,
      _website,
      _city,
      _region,
      _phone,
      _password,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _emailChanged =>
      _email.text.trim().toLowerCase() != _user.email.toLowerCase();

  void _clearError(String field) {
    if (_serverErrors.containsKey(field)) {
      setState(() => _serverErrors.remove(field));
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    final form = _profileKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    // Seuls les champs modifiés sont envoyés. La ville et la région, qui ne
    // peuvent pas être vides côté serveur, ne sont envoyées que si renseignées.
    final fullName = _fullName.text.trim();
    final username = _username.text.trim();
    final email = _email.text.trim();
    final bio = _bio.text.trim();
    final website = _website.text.trim();
    final city = _city.text.trim();
    final region = _region.text.trim();

    final changedName = fullName != _user.fullName;
    final changedUsername = username != _user.username;
    final changedBio = bio != (_user.bio ?? '');
    final changedWebsite = website != (_user.website ?? '');
    final changedCity = city.isNotEmpty && city != (_user.city ?? '');
    final changedRegion = region.isNotEmpty && region != (_user.region ?? '');
    final anyChange =
        changedName ||
        changedUsername ||
        _emailChanged ||
        changedBio ||
        changedWebsite ||
        changedCity ||
        changedRegion;
    if (!anyChange) {
      _toast('Aucune modification.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
      _serverErrors.clear();
    });
    try {
      final updated = await ref
          .read(profileRepositoryProvider)
          .updateProfile(
            fullName: changedName ? fullName : null,
            username: changedUsername ? username : null,
            email: _emailChanged ? email : null,
            bio: changedBio ? bio : null,
            website: changedWebsite ? website : null,
            city: changedCity ? city : null,
            region: changedRegion ? region : null,
            currentPassword: _emailChanged ? _password.text : null,
          );
      ref.read(sessionControllerProvider.notifier).updateUser(updated);
      _password.clear();
      if (mounted) {
        setState(() => _user = updated);
        _toast('Profil mis à jour.');
      }
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          for (final entry in e.fieldErrors.entries) {
            if (entry.value.isNotEmpty) {
              _serverErrors[entry.key] = entry.value.first;
            }
          }
          _error = _serverErrors.isEmpty ? e.userMessage : null;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _savePhone({required bool remove}) async {
    if (_savingPhone) {
      return;
    }
    if (!remove) {
      final form = _phoneKey.currentState;
      if (form == null || !form.validate()) {
        return;
      }
    }
    final digits = _phone.text.trim();
    final value = (remove || digits.isEmpty) ? null : '$_prefix$digits';
    FocusScope.of(context).unfocus();
    setState(() {
      _savingPhone = true;
      _phoneError = null;
    });
    try {
      final updated = await ref
          .read(profileRepositoryProvider)
          .updatePhone(value);
      ref.read(sessionControllerProvider.notifier).updateUser(updated);
      if (mounted) {
        setState(() {
          _user = updated;
          if (value == null) {
            _phone.clear();
          }
        });
        _toast(value == null ? 'Numéro supprimé.' : 'Numéro enregistré.');
      }
    } on ApiError catch (e) {
      if (mounted) {
        setState(
          () =>
              _phoneError = e.firstFieldError('phone_number') ?? e.userMessage,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _savingPhone = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Form(
          key: _profileKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                ErrorMessage(_error!),
                const SizedBox(height: 16),
              ],
              AppTextField(
                controller: _fullName,
                label: 'Nom complet',
                keyboardType: TextInputType.name,
                textInputAction: TextInputAction.next,
                validator: Validators.fullName,
                errorText: _serverErrors['full_name'],
                onChanged: (_) => _clearError('full_name'),
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _username,
                label: "Nom d'utilisateur",
                textInputAction: TextInputAction.next,
                validator: Validators.username,
                errorText: _serverErrors['username'],
                onChanged: (_) => _clearError('username'),
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _email,
                label: 'Adresse email',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: Validators.email,
                errorText: _serverErrors['email'],
                onChanged: (_) => _clearError('email'),
              ),
              if (_emailChanged) ...[
                const SizedBox(height: 8),
                Text(
                  'Changer d\'adresse demande votre mot de passe actuel.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                PasswordField(
                  controller: _password,
                  label: 'Mot de passe actuel',
                  textInputAction: TextInputAction.next,
                  validator: (v) => Validators.required(
                    v,
                    'Saisissez votre mot de passe actuel.',
                  ),
                  errorText: _serverErrors['current_password'],
                  onChanged: (_) => _clearError('current_password'),
                ),
              ],
              const SizedBox(height: 16),
              AppTextField(
                controller: _bio,
                label: 'Présentation',
                maxLength: 500,
                validator: Validators.bio,
                errorText: _serverErrors['bio'],
                onChanged: (_) => _clearError('bio'),
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _website,
                label: 'Site web',
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
                validator: Validators.websiteOptional,
                errorText: _serverErrors['website'],
                onChanged: (_) => _clearError('website'),
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _city,
                label: 'Ville',
                textInputAction: TextInputAction.next,
                validator: Validators.maxLength100,
                errorText: _serverErrors['city'],
                onChanged: (_) => _clearError('city'),
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _region,
                label: 'Région',
                textInputAction: TextInputAction.done,
                validator: Validators.maxLength100,
                errorText: _serverErrors['region'],
                onChanged: (_) => _clearError('region'),
              ),
              const SizedBox(height: 16),
              LoadingButton(
                label: 'Enregistrer',
                isLoading: _saving,
                onPressed: _save,
              ),
            ],
          ),
        ),
        const Divider(height: 48),
        Text('Numéro de téléphone', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Facultatif. Numéro sénégalais uniquement.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Form(
          key: _phoneKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 9,
                validator: Validators.senegalPhoneDigitsOptional,
                decoration: InputDecoration(
                  labelText: 'Numéro',
                  prefixText: '$_prefix ',
                  counterText: '',
                  border: const OutlineInputBorder(),
                  errorText: _phoneError,
                ),
                onChanged: (_) {
                  if (_phoneError != null) {
                    setState(() => _phoneError = null);
                  }
                },
              ),
              const SizedBox(height: 12),
              LoadingButton(
                label: 'Enregistrer le numéro',
                isLoading: _savingPhone,
                onPressed: () => _savePhone(remove: false),
              ),
              if (_user.phoneNumber != null)
                TextButton(
                  onPressed: _savingPhone
                      ? null
                      : () => _savePhone(remove: true),
                  child: const Text('Supprimer mon numéro'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
