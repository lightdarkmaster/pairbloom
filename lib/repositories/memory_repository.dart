import '../core/database/database_helper.dart';
import '../models/memory.dart';
import 'base_repository.dart';

class MemoryRepository extends BaseRepository<Memory> {
  MemoryRepository(DatabaseHelper db) : super(db);

  @override
  String get table => 'memories';
  @override
  List<String> get searchColumns => ['title', 'description', 'category'];
  @override
  Memory fromMap(Map<String, Object?> map) => Memory.fromMap(map);

  @override
  void validate(Memory m) {
    if (m.title.trim().isEmpty) throw ValidationException('Please give this memory a title.');
    if (m.memoryDate.isAfter(DateTime.now().add(const Duration(days: 1)))) {
      throw ValidationException('A memory cannot be dated in the future.');
    }
  }

  /// Inserts the memory and its photos atomically.
  @override
  Future<int> insert(Memory m) async {
    validate(m);
    return db.transaction((txn) async {
      final id = await db.insert(table, m.toMap(), txn: txn);
      for (final path in m.photoPaths) {
        await db.insert('memory_photos', {'memory_id': id, 'file_path': path}, txn: txn);
      }
      return id;
    });
  }

  /// Updates the memory and replaces its photo list atomically.
  @override
  Future<int> update(Memory m) async {
    final id = m.id;
    if (id == null) throw ValidationException('Cannot update an unsaved memory.');
    validate(m);
    return db.transaction((txn) async {
      final changed = await db.update(table, id, m.toMap(), txn: txn);
      await txn.delete('memory_photos', where: 'memory_id = ?', whereArgs: [id]);
      for (final path in m.photoPaths) {
        await db.insert('memory_photos', {'memory_id': id, 'file_path': path}, txn: txn);
      }
      return changed;
    });
  }

  /// Returns photo file paths of a memory so callers can delete the files
  /// after deleting the row (rows cascade, files do not).
  Future<List<String>> photoPathsOf(int memoryId) async =>
      (await _photosFor([memoryId]))[memoryId] ?? const [];

  Future<Map<int, List<String>>> _photosFor(List<int> ids) async {
    if (ids.isEmpty) return {};
    final rows = await db.getAll('memory_photos',
        where: 'memory_id IN (${List.filled(ids.length, '?').join(',')})',
        whereArgs: ids,
        orderBy: 'id ASC');
    final out = <int, List<String>>{};
    for (final r in rows) {
      out.putIfAbsent(r['memory_id'] as int, () => []).add(r['file_path'] as String);
    }
    return out;
  }

  Future<List<Memory>> _withPhotos(List<Map<String, Object?>> rows) async {
    final photos = await _photosFor(rows.map((r) => r['id'] as int).toList());
    return rows.map((r) => Memory.fromMap(r, photos: photos[r['id']] ?? const [])).toList();
  }

  @override
  Future<List<Memory>> getAll(
      {String? where, List<Object?>? whereArgs, String? orderBy, int? limit}) async {
    final rows = await db.getAll(table,
        where: where,
        whereArgs: whereArgs,
        orderBy: orderBy ?? 'memory_date DESC, id DESC',
        limit: limit);
    return _withPhotos(rows);
  }

  @override
  Future<Memory?> getById(int id) async {
    final row = await db.getById(table, id);
    return row == null ? null : (await _withPhotos([row])).first;
  }

  Future<List<Memory>> recent({int limit = 5}) => getAll(limit: limit);

  /// Search + optional category / favorites filters for the timeline screen.
  Future<List<Memory>> filter(
      {String query = '', String? category, bool favoritesOnly = false}) async {
    final clauses = <String>[];
    final args = <Object?>[];
    if (category != null) {
      clauses.add('category = ?');
      args.add(category);
    }
    if (favoritesOnly) clauses.add('is_favorite = 1');
    final rows = await db.search(table,
        columns: searchColumns,
        query: query,
        where: clauses.isEmpty ? null : clauses.join(' AND '),
        whereArgs: args,
        orderBy: 'memory_date DESC, id DESC');
    return _withPhotos(rows);
  }

  Future<void> setFavorite(int id, bool value) =>
      db.update(table, id, {'is_favorite': value ? 1 : 0});
}
