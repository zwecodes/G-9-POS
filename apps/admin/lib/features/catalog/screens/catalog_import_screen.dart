import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../dashboard/providers/dashboard_providers.dart';

class CatalogImportScreen extends ConsumerStatefulWidget {
  const CatalogImportScreen({super.key});

  @override
  ConsumerState<CatalogImportScreen> createState() =>
      _CatalogImportScreenState();
}

class _CatalogImportScreenState extends ConsumerState<CatalogImportScreen> {
  String? _fileName;
  List<int>? _bytes;
  String? _error;
  String? _success;
  var _busy = false;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const Text('Catalog import', style: AppTextStyles.title),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Upload a UTF-8 CSV with columns: name, price_mmk, and optional '
          'cost_price_mmk, barcode, category, unit, low_stock_threshold, '
          'initial_stock. The whole file succeeds or nothing is saved.',
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xl),
        OutlinedButton(
          onPressed: _busy ? null : _pickFile,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(AppSpacing.keyActionButton),
          ),
          child: Text(
            _fileName == null ? 'Choose CSV file' : 'Chosen: $_fileName',
            style: AppTextStyles.body,
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
        const SizedBox(height: AppSpacing.xl),
        PrimaryButton(
          label: 'Import catalog',
          busy: _busy,
          onPressed: _busy || _bytes == null ? null : _import,
        ),
      ],
    );
  }

  Future<void> _pickFile() async {
    setState(() {
      _error = null;
      _success = null;
    });
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      setState(() => _error = 'Could not read that file. Try again.');
      return;
    }
    setState(() {
      _fileName = file.name;
      _bytes = bytes;
    });
  }

  Future<void> _import() async {
    final bytes = _bytes;
    final name = _fileName;
    if (bytes == null || name == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      final result = await ref.read(dashboardRepositoryProvider).importCatalog(
            fileName: name,
            bytes: bytes,
          );
      ref.invalidate(overviewProvider);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _success =
            'Imported ${result.productsCreated} products, '
            '${result.categoriesCreated} categories, '
            '${result.inventoryEventsCreated} stock events.';
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      final details = error.details;
      var message = error.message;
      if (details is List && details.isNotEmpty) {
        final first = details.first;
        if (first is Map && first['message'] is String) {
          message = '$message ${first['message']}';
        }
      }
      setState(() {
        _busy = false;
        _error = message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not import the catalog. Try again.';
      });
    }
  }
}
