import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/ui_primitives.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('G9POS', style: AppTextStyles.saleTotal),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Shop dashboard — monitoring and catalog import',
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: AppSpacing.xl),
                TextField(
                  controller: _username,
                  autofillHints: const [AutofillHints.username],
                  decoration: const InputDecoration(labelText: 'Username'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _password,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: const InputDecoration(labelText: 'Password'),
                  onSubmitted: (_) => _submit(),
                ),
                ErrorText(session.error),
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: 'Sign in',
                  busy: session.busy,
                  onPressed: session.busy ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    await ref.read(sessionProvider.notifier).login(
          _username.text,
          _password.text,
        );
  }
}
