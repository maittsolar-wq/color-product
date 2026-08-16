import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';

import '../models/category_model.dart';
import '../models/lesson_model.dart';

/// SINGLE SOURCE OF TRUTH for categories and lessons. Home, Library, Search,
/// and Profile all read through this one repository — none of them parse
/// assets/data/lessons.json (or categories.json) directly, and none keeps a
/// second copy of the lesson list.
class LessonRepository extends ChangeNotifier {
  List<CategoryModel> _categories = const [];
  List<LessonModel> _lessons = const [];
  Map<String, LessonModel> _lessonsById = const {};
  bool _loaded = false;

  bool get isLoaded => _loaded;
  List<CategoryModel> get categories => _categories;
  List<LessonModel> get lessons => _lessons;

  Future<void> load() async {
    if (_loaded) return;
    final categoriesJson = await rootBundle.loadString('assets/data/categories.json');
    final lessonsJson = await rootBundle.loadString('assets/data/lessons.json');

    final categories = (json.decode(categoriesJson) as List)
        .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final lessons = (json.decode(lessonsJson) as List)
        .map((e) => LessonModel.fromJson(e as Map<String, dynamic>))
        .toList();

    _categories = categories;
    _lessons = lessons;
    _lessonsById = {for (final lesson in lessons) lesson.id: lesson};
    _loaded = true;
    notifyListeners();
  }

  LessonModel? findById(String lessonId) => _lessonsById[lessonId];

  /// Lessons in a category, in the category's own approved display order.
  List<LessonModel> byCategory(String categoryId) {
    final matches = _lessons.where((l) => l.categoryId == categoryId).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return matches;
  }

  /// Case-insensitive substring match against title only — the same
  /// metadata table Home/Library/Profile already read, never a separate
  /// search index (see functional-spec.md FS-SEARCH-002).
  List<LessonModel> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return _lessons.where((l) => l.title.toLowerCase().contains(q)).toList();
  }
}
