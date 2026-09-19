import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final isOwner = ref.watch(sessionProvider).operatorRole == 'owner';
    final categories = ref.watch(categoryListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
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
                ? const EmptyState(
                    icon: Icons.lock_outline,
                    message: 'Only the owner can manage categories.',
                  )
                : categories.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stack) => const EmptyState(
                      icon: Icons.error_outline,
                      message: 'Could not load categories. Try again.',
                    ),
                    data: (list) {
                      if (list.isEmpty) {
                        return EmptyState(
                          icon: Icons.category_outlined,
                          message: 'No categories yet — add the first one',
                          action: TextButton(
                            onPressed: () => _editCategory(),
                            child: const Text('Add category'),
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
                              tooltip: 'Delete',
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
    final controller = TextEditingController(text: name);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            id == null ? 'Add category' : 'Edit category',
            style: AppTextStyles.title,
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Name *'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Save', style: AppTextStyles.body),
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
      setState(() => _error = 'Could not save the category. Try again.');
    }
  }

  Future<void> _confirmDelete(String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete this category?', style: AppTextStyles.title),
          content: Text(
            '"$name" will be removed. Products in it must be moved first.',
            style: AppTextStyles.body,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Keep',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'Delete',
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
      setState(() => _error = 'Could not delete the category. Try again.');
    }
  }
}
