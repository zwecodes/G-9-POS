import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../dashboard/providers/dashboard_providers.dart';

class StaffScreen extends ConsumerStatefulWidget {
  const StaffScreen({super.key});

  @override
  ConsumerState<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends ConsumerState<StaffScreen> {
  final _name = TextEditingController();
  final _pin = TextEditingController();
  String? _error;
  String? _success;
  var _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(usersProvider);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const Text('Staff', style: AppTextStyles.title),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'One staff account at launch. They unlock the POS with a PIN and can '
          'sell and add expenses — not products, inventory, or reports.',
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xl),
        users.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Text(
            error is ApiException
                ? error.message
                : 'Could not load users. Try again.',
            style: AppTextStyles.caption.copyWith(color: AppColors.error),
          ),
          data: (list) {
            final staff = list.where((u) => u.role == 'staff').toList();
            if (staff.isEmpty) {
              return Text(
                'No staff account yet.',
                style: AppTextStyles.caption,
              );
            }
            return Column(
              children: [
                for (final user in staff)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(user.name, style: AppTextStyles.body),
                    subtitle: Text('Staff', style: AppTextStyles.caption),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.xl),
        const Text('Create staff', style: AppTextStyles.sectionHeader),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Name *'),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _pin,
          keyboardType: TextInputType.number,
          maxLength: 4,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'PIN (4 digits) *'),
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
          label: 'Create staff account',
          busy: _busy,
          onPressed: _busy ? null : _create,
        ),
      ],
    );
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    final pin = _pin.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a name.');
      return;
    }
    if (pin.length != 4) {
      setState(() => _error = 'PIN must be exactly 4 digits.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      final user = await ref.read(dashboardRepositoryProvider).createStaff(
            name: name,
            pin: pin,
          );
      ref.invalidate(usersProvider);
      if (!mounted) return;
      _name.clear();
      _pin.clear();
      setState(() {
        _busy = false;
        _success = 'Created staff account for ${user.name}.';
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not create staff. Try again.';
      });
    }
  }
}
