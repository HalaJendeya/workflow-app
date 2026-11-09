import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workflow_app/core/design_system/app_icons.dart';
import 'package:workflow_app/core/design_system/app_theme.dart';
import 'package:workflow_app/core/network/api_exception.dart';
import 'package:workflow_app/core/widgets/api_error_text.dart';
import 'package:workflow_app/core/widgets/form_widgets.dart';
import 'package:workflow_app/core/widgets/module_widgets.dart';
import 'package:workflow_app/core/widgets/wf_components.dart';
import 'package:workflow_app/features/auth/application/session_controller.dart';
import 'package:workflow_app/features/auth/domain/session.dart';
import 'package:workflow_app/features/finance/presentation/finance_common.dart';
import 'package:workflow_app/features/profile/data/profile_repository.dart';
import 'package:workflow_app/l10n/gen/app_localizations.dart';

/// Password rule from the Figma hint: 8+ characters mixing letters,
/// numbers and symbols.
bool isStrongPassword(String v) =>
    v.length >= 8 &&
    RegExp('[A-Za-z]').hasMatch(v) &&
    RegExp('[0-9]').hasMatch(v) &&
    RegExp('[^A-Za-z0-9]').hasMatch(v);

/// Figma "Profile Details" (643:33288): identity card, personal information,
/// change password and the delete-account danger zone.
class ProfileScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(profileProvider);
    return ModulePage(
      title: l10n.profileDetails,
      description: l10n.profileDetailsBody,
      children: [
        ...profile.when(
          data: (p) => [
            _IdentityCard(profile: p),
            _PersonalInfoCard(profile: p),
          ],
          loading: () => [
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
          ],
          error: (e, _) => [
            ModuleCard(
              child: Column(
                children: [
                  Text(localizedError(l10n, e)),
                  TextButton(
                    onPressed: () => ref.invalidate(profileProvider),
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            ),
          ],
        ),
        _Heading(title: l10n.changePassword, body: l10n.changePasswordBody),
        const _PasswordCard(),
        _Heading(title: l10n.deleteAccount, body: l10n.deleteAccountBody),
        const _DangerZoneCard(),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const new({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: AppTextStyles.mobileLgSemiBold.copyWith(
          color: AppColors.textPrimary,
        ),
      ),
      const SizedBox(height: 12),
      Text(
        body,
        style: AppTextStyles.mobileBaseRegular.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    ],
  );
}

class _ActionButtons extends StatelessWidget {
  const new({
    required this.saveLabel,
    required this.onSave,
    required this.onCancel,
    this.busy = false,
    this.saveColor = AppColors.primary,
    this.saveKey,
  });

  final String saveLabel;
  final VoidCallback? onSave;
  final VoidCallback onCancel;
  final bool busy;
  final Color saveColor;
  final Key? saveKey;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      WfPrimaryButton(
        key: saveKey,
        label: saveLabel,
        loading: busy,
        height: 44,
        color: saveColor,
        onPressed: onSave,
      ),
      const SizedBox(height: 8),
      SizedBox(
        height: 44,
        child: OutlinedButton(
          onPressed: onCancel,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: const BorderSide(color: ModuleColors.chipBorder),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.button),
            ),
            textStyle: AppTextStyles.mobileBaseSemiBold,
          ),
          child: Text(AppLocalizations.of(context).cancel),
        ),
      ),
    ],
  );
}

class _IdentityCard extends ConsumerWidget {
  const new({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final portal =
        ref.watch(sessionControllerProvider).value?.portal ?? Portal.client;
    Widget field(String label, String value) => Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.mobileXsRegular.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTextStyles.mobileBaseSemiBold.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
    return ModuleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 92,
                height: 92,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  profile.initials,
                  style: AppTextStyles.choiceTitle.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name ?? profile.displayName,
                      style: AppTextStyles.mobileLgSemiBold.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      portal == Portal.client
                          ? l10n.roleClient
                          : l10n.roleEmployee,
                      style: AppTextStyles.mobileBaseRegular.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          WfPrimaryButton(
            key: const Key('upload-image'),
            label: l10n.uploadNewImage,
            height: 44,
            // The multipart endpoint is documented; the app has no image
            // picker yet, and the message says exactly that.
            onPressed: () => showSnack(context, l10n.imagePickerPending),
          ),
          field(l10n.accountId, '#${profile.id}'),
          field(l10n.emailLabel, profile.email),
        ],
      ),
    );
  }
}

class _PersonalInfoCard extends ConsumerStatefulWidget {
  const new({required this.profile});

  final UserProfile profile;

  @override
  ConsumerState<_PersonalInfoCard> createState() => _PersonalInfoCardState();
}

class _PersonalInfoCardState extends ConsumerState<_PersonalInfoCard> {
  final _form = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  Map<String, List<String>> _serverErrors = const {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  void _reset() {
    final parts = (widget.profile.name ?? '').trim().split(RegExp(r'\s+'));
    _first.text = parts.first;
    _last.text = parts.skip(1).join(' ');
    _email.text = widget.profile.email;
    _serverErrors = const {};
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _serverErrors = const {});
    if (!validateAndReveal(_form)) return;
    final l10n = AppLocalizations.of(context);
    final name = '${_first.text.trim()} ${_last.text.trim()}'.trim();
    final email = _email.text.trim();
    setState(() => _saving = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .update(
            name: name == widget.profile.name ? null : name,
            email: email == widget.profile.email ? null : email,
          );
      ref.invalidate(profileProvider);
      if (mounted) showSnack(context, l10n.profileSaved);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _serverErrors = e.fieldErrors);
      showSnack(context, localizedError(l10n, e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final portal =
        ref.watch(sessionControllerProvider).value?.portal ?? Portal.client;
    final emailError = _serverErrors['email']?.first;
    final nameError = _serverErrors['name']?.first;
    return ModuleCard(
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.keepProfileUpToDate,
              style: AppTextStyles.mobileLgSemiBold.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.keepProfileUpToDateBody,
              style: AppTextStyles.mobileBaseRegular.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.personalInformation,
              style: AppTextStyles.mobileLgSemiBold.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            TextInputField(
              fieldKey: const Key('profile-first'),
              label: l10n.firstName,
              controller: _first,
            ),
            if (nameError != null) _ServerError(nameError),
            const SizedBox(height: 16),
            TextInputField(
              fieldKey: const Key('profile-last'),
              label: l10n.lastName,
              controller: _last,
              required: false,
            ),
            const SizedBox(height: 16),
            TextInputField(
              fieldKey: const Key('profile-email'),
              label: l10n.emailAddress,
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              validator: (v) =>
                  RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v!.trim())
                  ? null
                  : l10n.validationEmail,
            ),
            if (emailError != null) _ServerError(emailError),
            const SizedBox(height: 16),
            _ReadOnlyField(
              label: l10n.roleLabel,
              value: portal == Portal.client
                  ? l10n.roleClient
                  : l10n.roleEmployee,
            ),
            const SizedBox(height: 16),
            _ActionButtons(
              saveKey: const Key('profile-save'),
              saveLabel: l10n.save,
              busy: _saving,
              onSave: _saving ? null : _save,
              onCancel: () => setState(_reset),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServerError extends StatelessWidget {
  const new(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(top: 6, start: 4),
    child: Text(
      text,
      style: AppTextStyles.mobileXsRegular.copyWith(
        color: ModuleColors.dangerFg,
      ),
    ),
  );
}

class _ReadOnlyField extends StatelessWidget {
  const new({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        label,
        style: AppTextStyles.mobileBaseSemiBold.copyWith(
          color: AppColors.textPrimary,
        ),
      ),
      const SizedBox(height: 8),
      Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(AppRadii.input),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value,
                style: AppTextStyles.mobileBaseRegular.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const WfSvg('field_arrow_down', size: 20),
          ],
        ),
      ),
    ],
  );
}

class _PasswordCard extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_PasswordCard> createState() => _PasswordCardState();
}

class _PasswordCardState extends ConsumerState<_PasswordCard> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  String? _currentError;
  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _clear() {
    _current.clear();
    _new.clear();
    _confirm.clear();
    setState(() => _currentError = null);
  }

  Future<void> _save() async {
    setState(() => _currentError = null);
    if (!validateAndReveal(_form)) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _saving = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .changePassword(oldPassword: _current.text, newPassword: _new.text);
      if (!mounted) return;
      _clear();
      showSnack(context, l10n.passwordChanged);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _currentError = e.firstErrorFor('old_password'));
      showSnack(context, localizedError(l10n, e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ModuleCard(
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WfTextField(
              key: const Key('pw-current'),
              label: l10n.currentPassword,
              controller: _current,
              icon: AppIcon.lock,
              hint: l10n.passwordHint,
              obscure: true,
              errorText: _currentError,
              validator: (v) =>
                  (v == null || v.isEmpty) ? l10n.validationRequired : null,
            ),
            const SizedBox(height: 16),
            WfTextField(
              key: const Key('pw-new'),
              label: l10n.newPassword,
              controller: _new,
              icon: AppIcon.lock,
              hint: l10n.passwordHint,
              obscure: true,
              validator: (v) =>
                  isStrongPassword(v ?? '') ? null : l10n.passwordRule,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.passwordRule,
              style: AppTextStyles.mobileXsRegular.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            WfTextField(
              key: const Key('pw-confirm'),
              label: l10n.confirmNewPassword,
              controller: _confirm,
              icon: AppIcon.lock,
              hint: l10n.passwordHint,
              obscure: true,
              validator: (v) => v == _new.text ? null : l10n.passwordsDontMatch,
            ),
            const SizedBox(height: 16),
            _ActionButtons(
              saveKey: const Key('pw-save'),
              saveLabel: l10n.save,
              busy: _saving,
              onSave: _saving ? null : _save,
              onCancel: _clear,
            ),
          ],
        ),
      ),
    );
  }
}

class _DangerZoneCard extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_DangerZoneCard> createState() => _DangerZoneCardState();
}

class _DangerZoneCardState extends ConsumerState<_DangerZoneCard> {
  bool _confirmed = false;
  bool _deleting = false;

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    if (!await confirmDelete(
      context,
      l10n.yourAccount,
      title: l10n.deleteAccountTitle,
      body: l10n.deleteAccountConfirmBody,
      confirmLabel: l10n.deleteAccount,
    )) {
      return;
    }
    setState(() => _deleting = true);
    try {
      await ref.read(profileRepositoryProvider).deleteAccount();
      await ref.read(sessionControllerProvider.notifier).logout();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, localizedError(l10n, e));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // The collection lists DELETE /employee/account/delete under the
    // permission boundary (expected 403): employees cannot delete their own
    // account, so they get the reason instead of a button that fails.
    final employee =
        ref.watch(sessionControllerProvider).value?.portal == Portal.employee;
    if (employee) {
      return ModuleCard(
        key: const Key('employee-delete-unavailable'),
        child: Text(
          l10n.employeeDeleteUnavailable,
          style: AppTextStyles.mobileBaseRegular.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
      );
    }
    return ModuleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.dangerZone,
            style: AppTextStyles.mobileLgSemiBold.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.deleteAccountWarning,
            style: AppTextStyles.mobileBaseRegular.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              WfCheckbox(
                key: const Key('confirm-deletion'),
                value: _confirmed,
                onChanged: (v) => setState(() => _confirmed = v),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.confirmDeletion,
                  style: AppTextStyles.mobileBaseRegular.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            l10n.deletionIrreversible,
            style: AppTextStyles.mobileXsRegular.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          _ActionButtons(
            saveKey: const Key('delete-account'),
            saveLabel: l10n.deleteAccount,
            saveColor: ModuleColors.dangerFg,
            busy: _deleting,
            onSave: _confirmed && !_deleting ? _delete : null,
            onCancel: () => setState(() => _confirmed = false),
          ),
        ],
      ),
    );
  }
}
