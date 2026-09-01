import 'package:tally/features/expenses/data/categories_repository.dart';
import 'package:tally/models/category.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Categories available for a group (global defaults + group-specific).
final categoriesProvider = FutureProvider.family<List<Category>, String>(
  (ref, groupId) => CategoriesRepository().fetchCategories(groupId: groupId),
);

// Map the DB icon-name hint to a Material icon (const, tree-shake friendly).
IconData iconForCategory(String name) {
  switch (name) {
    case 'restaurant':
      return Icons.restaurant;
    case 'shopping_cart':
      return Icons.shopping_cart;
    case 'home':
      return Icons.home;
    case 'directions_car':
      return Icons.directions_car;
    case 'movie':
      return Icons.movie;
    case 'favorite':
      return Icons.favorite;
    case 'flight':
      return Icons.flight;
    case 'shopping_bag':
      return Icons.shopping_bag;
    case 'bolt':
      return Icons.bolt;
    case 'more_horiz':
      return Icons.more_horiz;
    default:
      return Icons.label;
  }
}
