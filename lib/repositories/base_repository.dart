import '../core/database/database_helper.dart';

abstract class DbModel {
  int? get id;
  Map<String, Object?> toMap();
}

/// Thrown for invalid user input before anything touches the database.
class ValidationException implements Exception {
  ValidationException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Reusable CRUD for every table that has an integer `id` primary key.
abstract class BaseRepository<T extends DbModel> {
  BaseRepository(this.db);
  final DatabaseHelper db;

  String get table;
  List<String> get searchColumns;
  T fromMap(Map<String, Object?> map);

  /// Override to reject incomplete or invalid records.
  void validate(T item) {}

  Future<int> insert(T item) async {
    validate(item);
    return db.insert(table, item.toMap());
  }

  Future<List<T>> getAll(
      {String? where, List<Object?>? whereArgs, String? orderBy, int? limit}) async {
    final rows = await db.getAll(table,
        where: where, whereArgs: whereArgs, orderBy: orderBy, limit: limit);
    return rows.map(fromMap).toList();
  }

  Future<T?> getById(int id) async {
    final row = await db.getById(table, id);
    return row == null ? null : fromMap(row);
  }

  Future<int> update(T item) async {
    final id = item.id;
    if (id == null) throw ValidationException('Cannot update an unsaved record.');
    validate(item);
    return db.update(table, id, item.toMap());
  }

  Future<int> delete(int id) => db.delete(table, id);

  Future<List<T>> search(String query, {String? orderBy, int? limit}) async {
    final rows = await db.search(table,
        columns: searchColumns, query: query, orderBy: orderBy, limit: limit);
    return rows.map(fromMap).toList();
  }
}
