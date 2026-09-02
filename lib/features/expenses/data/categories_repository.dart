import 'package:tally/core/supabase_client.dart';
import 'package:tally/models/category.dart';

class CategoriesRepository {
  // Global default categories plus any this group has defined.
  Future<List<Category>> fetchCategories({required String groupId}) async {
    final data = await supabase
        .from('categories')
        .select()
        .or('group_id.is.null,group_id.eq.$groupId')
        .order('name');
    return (data as List)
        .map((e) => Category.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // group_id is required here — a null group_id is a global default, which
  // "members manage group categories" (0001_init.sql) deliberately rejects
  // from the client.
  Future<void> createCategory({
    required String groupId,
    required String name,
    required String icon,
  }) async {
    await supabase.from('categories').insert({
      'group_id': groupId,
      'name': name.trim(),
      'icon': icon,
    });
  }

  Future<void> updateCategory({
    required String id,
    required String name,
    required String icon,
  }) async {
    await supabase
        .from('categories')
        .update({'name': name.trim(), 'icon': icon}).eq('id', id);
  }

  // Any expense, recurring template or tag pointing at this category falls
  // back to uncategorized (on delete set null, migration 0012) rather than
  // blocking the delete.
  Future<void> deleteCategory({required String id}) async {
    await supabase.from('categories').delete().eq('id', id);
  }
}
