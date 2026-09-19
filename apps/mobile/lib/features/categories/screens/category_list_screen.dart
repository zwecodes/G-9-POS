import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/repository_exception.dart';
import '../../../shared/widgets/app_status.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/category_providers.dart';

class CategoryListScreen extends ConsumerStatefulWidget {
  const CategoryListScreen({super.key});

  @override
  ConsumerState<CategoryListScreen> createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends ConsumerState<CategoryListScreen> {
  String? _error;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isOwner = ref.watch(sessionProvider).operatorRole == 'owner';
    final categories = ref.watch(categoryListProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.categoriesTitle),
        actions: const [SyncStatusButton()],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                0,
              ),
              child: ErrorText(_error),
            ),
          Expanded(
            child: !isOwner
                ? EmptyState(
                    icon: Icons.lock_outline,
                    message: l10n.categoriesOwnerOnly,
                  )
                : categories.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stack) => EmptyState(
                      icon: Icons.error_outline,
                      message: l10n.couldNotLoadCategories,
                    ),
                    data: (list) {
                      if (list.isEmpty) {
                        return EmptyState(
                          icon: Icons.category_outlined,
                          message: l10n.noCategoriesYet,
                          action: TextButton(
                            onPressed: () => _editCategory(),
                            child: Text(l10n.addCategory),
                          ),
                        );
                      }
                      return ListView.separated(
                        itemCount: list.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final category = list[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            title: Text(
                              category.name,
                              style: AppTextStyles.cartItemName,
                            ),
                            onTap: () => _editCategory(
                              id: category.id,
                              name: category.name,
                              sortOrder: category.sortOrder,
                            ),
                            trailing: IconButton(
                              tooltip: l10n.delete,
                              onPressed: () => _confirmDelete(category.id, category.name),
                              icon: Icon(
                                Icons.delete_outline,
                                color: AppColors.error,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: isOwner
          ? FloatingActionButton(
              backgroundColor: AppColors.primary,
              onPressed: () => _editCategory(),
              child: const Icon(Icons.add, color: AppColors.onPrimary),
            )
          : null,
    );
  }

  Future<void> _editCategory({
    String? id,
    String name = '',
    int sortOrder = 0,
  }) async {
    final l10n = context.l10n;
    final controller = TextEditingController(text: name);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        final dialogL10n = context.l10n;
        return AlertDialog(
          title: Text(
            id == null ? dialogL10n.addCategory : dialogL10n.editCategory,
            style: AppTextStyles.title,
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(labelText: dialogL10n.nameRequired),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                dialogL10n.cancel,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: Text(dialogL10n.save, style: AppTextStyles.body),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (result == null || !mounted) return;
    setState(() => _error = null);
    try {
      final repo = ref.read(categoryRepositoryProvider);
      if (id == null) {
        await repo.create(name: result);
      } else {
        await repo.update(id: id, name: result, sortOrder: sortOrder);
      }
    } on RepositoryException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = l10n.couldNotSaveCategory);
    }
  }

  Future<void> _confirmDelete(String id, String name) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        final dialogL10n = context.l10n;
        return AlertDialog(
          title: Text(dialogL10n.deleteCategoryTitle, style: AppTextStyles.title),
          content: Text(
            dialogL10n.deleteCategoryBody(name),
            style: AppTextStyles.body,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                dialogL10n.keep,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                dialogL10n.delete,
                style: AppTextStyles.body.copyWith(color: AppColors.error),
              ),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;
    setState(() => _error = null);
    try {
      await ref.read(categoryRepositoryProvider).delete(id);
    } on RepositoryException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = l10n.couldNotDeleteCategory);
    }
  }
}
