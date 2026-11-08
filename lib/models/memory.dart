import '../core/utilities/date_helper.dart';
import '../repositories/base_repository.dart';

class Memory implements DbModel {
  Memory({
    this.id,
    required this.coupleId,
    required this.title,
    this.description,
    required this.memoryDate,
    this.category = 'Other',
    this.isFavorite = false,
    this.photoPaths = const [],
  });

  @override
  final int? id;
  final int coupleId;
  final String title;
  final String? description;
  final DateTime memoryDate;
  final String category;
  final bool isFavorite;

  /// Loaded from the `memory_photos` table (not a column of `memories`).
  final List<String> photoPaths;

  Memory copyWith({
    int? id,
    String? title,
    String? description,
    DateTime? memoryDate,
    String? category,
    bool? isFavorite,
    List<String>? photoPaths,
  }) =>
      Memory(
        id: id ?? this.id,
        coupleId: coupleId,
        title: title ?? this.title,
        description: description ?? this.description,
        memoryDate: memoryDate ?? this.memoryDate,
        category: category ?? this.category,
        isFavorite: isFavorite ?? this.isFavorite,
        photoPaths: photoPaths ?? this.photoPaths,
      );

  factory Memory.fromMap(Map<String, Object?> m, {List<String> photos = const []}) =>
      Memory(
        id: m['id'] as int?,
        coupleId: m['couple_id'] as int,
        title: m['title'] as String,
        description: m['description'] as String?,
        memoryDate: DateTime.parse(m['memory_date'] as String),
        category: m['category'] as String,
        isFavorite: (m['is_favorite'] as int) == 1,
        photoPaths: photos,
      );

  @override
  Map<String, Object?> toMap() => {
        'id': id,
        'couple_id': coupleId,
        'title': title.trim(),
        'description': description?.trim().isEmpty ?? true ? null : description!.trim(),
        'memory_date': DateHelper.toDb(memoryDate),
        'category': category,
        'is_favorite': isFavorite ? 1 : 0,
      };
}
