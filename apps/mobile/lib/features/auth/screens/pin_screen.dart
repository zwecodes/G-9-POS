import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final session = ref.watch(sessionProvider);
    final users = ref.watch(unlockableUsersProvider);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: users.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => const EmptyState(
              icon: Icons.lock,
              message: 'Could not load staff. Try again.',
            ),
            data: (list) {
              if (list.isEmpty) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Unlock this device', style: AppTextStyles.title),
                    const SizedBox(height: AppSpacing.md),
                    const Text(
                      'No staff PINs on this device yet. Continue as the signed-in owner.',
                      style: AppTextStyles.body,
                    ),
                    ErrorText(session.error),
                    const SizedBox(height: AppSpacing.lg),
                    PrimaryButton(
                      label: 'Continue',
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
                  const Text('Who is selling?', style: AppTextStyles.title),
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
                    decoration: const InputDecoration(labelText: 'PIN'),
                    onSubmitted: (_) => _unlock(),
                  ),
                  ErrorText(session.error),
                  const SizedBox(height: AppSpacing.lg),
                  PrimaryButton(
                    label: 'Unlock',
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
