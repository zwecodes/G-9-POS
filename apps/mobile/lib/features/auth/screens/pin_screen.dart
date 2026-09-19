import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_ext.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../providers/auth_providers.dart';

class PinScreen extends ConsumerStatefulWidget {
  const PinScreen({super.key});

  @override
  ConsumerState<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends ConsumerState<PinScreen> {
  String? _userId;
  final _pin = TextEditingController();

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = ref.watch(sessionProvider);
    final users = ref.watch(unlockableUsersProvider);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: users.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => EmptyState(
              icon: Icons.lock,
              message: l10n.couldNotLoadStaff,
            ),
            data: (list) {
              if (list.isEmpty) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l10n.unlockThisDevice, style: AppTextStyles.title),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      context.l10n.noStaffPinsYet,
                      style: AppTextStyles.body,
                    ),
                    ErrorText(session.error),
                    const SizedBox(height: AppSpacing.lg),
                    PrimaryButton(
                      label: l10n.continueLabel,
                      onPressed: session.hasJwt
                          ? () => ref.read(sessionProvider.notifier).unlockAsCachedUser()
                          : null,
                    ),
                  ],
                );
              }
              _userId ??= list.first.id;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.whoIsSelling, style: AppTextStyles.title),
                  const SizedBox(height: AppSpacing.lg),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: list.any((u) => u.id == _userId) ? _userId : list.first.id,
                    items: [
                      for (final user in list)
                        DropdownMenuItem(value: user.id, child: Text(user.name)),
                    ],
                    onChanged: (id) => setState(() => _userId = id),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _pin,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    decoration: InputDecoration(labelText: l10n.pin),
                    onSubmitted: (_) => _unlock(),
                  ),
                  ErrorText(session.error),
                  const SizedBox(height: AppSpacing.lg),
                  PrimaryButton(
                    label: l10n.unlock,
                    busy: session.busy,
                    onPressed: _unlock,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _unlock() async {
    final userId = _userId;
    if (userId == null) return;
    await ref.read(sessionProvider.notifier).unlockWithPin(
          userId: userId,
          pin: _pin.text,
        );
  }
}
