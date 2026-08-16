// Mirrors the approved real 25-lesson dataset (see
// 03-design/prototype/data/lessons.json, the design source of truth this
// Flutter model is synced against). `id` is the stable lesson identity used
// for progress lookups — never regenerated.
class LessonModel {
  const LessonModel({
    required this.id,
    required this.title,
    required this.categoryId,
    required this.artworkAsset,
    required this.thumbnailAsset,
    required this.isPremium,
    required this.sortOrder,
  });

  final String id;
  final String title;
  final String categoryId;

  /// 800x800 source artwork — Editor use only. Never load this in a
  /// discovery/list context (Home/Library/Search/Profile).
  final String artworkAsset;

  /// 250x250 thumbnail — Home/Library/Search/Profile use only. Never load
  /// this in the Editor.
  final String thumbnailAsset;

  final bool isPremium;
  final int sortOrder;

  factory LessonModel.fromJson(Map<String, dynamic> json) {
    return LessonModel(
      id: json['id'] as String,
      title: json['title'] as String,
      categoryId: json['categoryId'] as String,
      artworkAsset: json['artwork'] as String,
      thumbnailAsset: json['thumbnail'] as String,
      isPremium: json['isPremium'] as bool,
      sortOrder: json['sortOrder'] as int,
    );
  }
}
