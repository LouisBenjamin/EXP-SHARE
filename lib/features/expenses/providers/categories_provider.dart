import 'package:tally/features/expenses/data/categories_repository.dart';
import 'package:tally/models/category.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Categories available for a group (global defaults + group-specific).
// Invalidate after createCategory/updateCategory/deleteCategory.
final categoriesProvider = FutureProvider.family<List<Category>, String>(
  (ref, groupId) => CategoriesRepository().fetchCategories(groupId: groupId),
);
