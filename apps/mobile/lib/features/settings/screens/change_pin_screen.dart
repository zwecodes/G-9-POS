import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/app_status.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../auth/providers/auth_providers.dart';

class ChangePinScreen extends ConsumerStatefulWidget {
  const ChangePinScreen({super.key});

  @override
  ConsumerState<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends ConsumerState<ChangePinScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  String? _success;
  var _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.changePinTitle),
        actions: const [SyncStatusButton()],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Text(
                  l10n.changePinHelp,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _current,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.currentPin,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _next,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.newPin,
                    hintText: l10n.pinHint,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _confirm,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.confirmNewPin,
                  ),
                ),
                ErrorText(_error),
                if (_success != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _success!,
                    style: AppTextStyles.body.copyWith(color: AppColors.success),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  label: l10n.savePin,
                  busy: _busy,
                  onPressed: _busy ? null : _save,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    setState(() {
      _error = null;
      _success = null;
    });
    final next = _next.text.trim();
    final confirm = _confirm.text.trim();
    if (next != confirm) {
      setState(() => _error = l10n.pinMismatch);
      return;
    }
    if (next.length < 4 || next.length > 8 || !RegExp(r'^\d+$').hasMatch(next)) {
      setState(() => _error = l10n.pinInvalid);
      return;
    }
    final operatorId = ref.read(sessionProvider).operatorId;
    if (operatorId == null || operatorId.isEmpty) {
      setState(() => _error = 'Sign in again to change your PIN.');
      return;
    }
    setState(() => _busy = true);
    final ok = await ref.read(pinServiceProvider).changePin(
          userId: operatorId,
          currentPin: _current.text.trim(),
          newPin: next,
        );
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _busy = false;
        _error = l10n.pinChangeFailed;
      });
      return;
    }
    _current.clear();
    _next.clear();
    _confirm.clear();
    setState(() {
      _busy = false;
      _success = l10n.pinSaved;
    });
  }
}
