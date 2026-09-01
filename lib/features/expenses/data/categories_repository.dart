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
}
