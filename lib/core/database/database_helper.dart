import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'database_migrations.dart';

/// Wraps low-level sqflite failures so the UI can show friendly messages.
class AppDatabaseException implements Exception {
  AppDatabaseException(this.message, [this.cause]);
  final String message;
  final Object? cause;
  @override
  String toString() => message;
}

/// Central database service: opens the DB, enforces foreign keys, exposes
/// reusable CRUD helpers, transactions, backup and restore.
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const dbFileName = 'pairbloom.db';
  Database? _db;

  Future<String> get _dbPath async =>
      p.join(await getDatabasesPath(), dbFileName);

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    try {
      return await openDatabase(
        await _dbPath,
        version: DatabaseMigrations.currentVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: DatabaseMigrations.onCreate,
        onUpgrade: DatabaseMigrations.onUpgrade,
      );
    } on DatabaseException catch (e) {
      throw AppDatabaseException('Could not open the database.', e);
    }
  }

  Future<T> _guard<T>(String op, Future<T> Function() action) async {
    try {
      return await action();
    } on DatabaseException catch (e) {
      final msg = e.toString();
      if (msg.contains('CHECK constraint') || msg.contains('NOT NULL')) {
        throw AppDatabaseException('Some required information is missing or invalid.', e);
      }
      if (msg.contains('FOREIGN KEY')) {
        throw AppDatabaseException('This record is linked to data that no longer exists.', e);
      }
      if (msg.contains('UNIQUE')) {
        throw AppDatabaseException('This record already exists.', e);
      }
      throw AppDatabaseException('Database error during $op.', e);
    }
  }

  // ---------------------------------------------------------------- CRUD ---

  Future<int> insert(String table, Map<String, Object?> values,
      {DatabaseExecutor? txn}) {
    return _guard('insert into $table', () async {
      final now = DateTime.now().toIso8601String();
      final data = Map<String, Object?>.from(values)
        ..remove('id')
        ..['created_at'] = now
        ..['updated_at'] = now;
      return (txn ?? await database).insert(table, data);
    });
  }

  Future<List<Map<String, Object?>>> getAll(String table,
      {String? where,
      List<Object?>? whereArgs,
      String? orderBy,
      int? limit,
      DatabaseExecutor? txn}) {
    return _guard('read $table', () async {
      return (txn ?? await database).query(table,
          where: where, whereArgs: whereArgs, orderBy: orderBy, limit: limit);
    });
  }

  Future<Map<String, Object?>?> getById(String table, int id,
      {DatabaseExecutor? txn}) {
    return _guard('read $table', () async {
      final rows = await (txn ?? await database)
          .query(table, where: 'id = ?', whereArgs: [id], limit: 1);
      return rows.isEmpty ? null : rows.first;
    });
  }

  /// Returns number of rows changed (0 when the id does not exist).
  Future<int> update(String table, int id, Map<String, Object?> values,
      {DatabaseExecutor? txn}) {
    return _guard('update $table', () async {
      final data = Map<String, Object?>.from(values)
        ..remove('id')
        ..remove('created_at')
        ..['updated_at'] = DateTime.now().toIso8601String();
      return (txn ?? await database)
          .update(table, data, where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<int> delete(String table, int id, {DatabaseExecutor? txn}) {
    return _guard('delete from $table', () async {
      return (txn ?? await database)
          .delete(table, where: 'id = ?', whereArgs: [id]);
    });
  }

  /// Case-insensitive LIKE search across [columns], with optional extra filter.
  Future<List<Map<String, Object?>>> search(String table,
      {required List<String> columns,
      required String query,
      String? where,
      List<Object?>? whereArgs,
      String? orderBy,
      int? limit}) {
    return _guard('search $table', () async {
      final q = query.trim();
      final clauses = <String>[];
      final args = <Object?>[];
      if (q.isNotEmpty) {
        final escaped =
            q.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
        clauses.add(
            '(${columns.map((c) => "$c LIKE ? ESCAPE '\\'").join(' OR ')})');
        args.addAll(List.filled(columns.length, '%$escaped%'));
      }
      if (where != null) {
        clauses.add('($where)');
        args.addAll(whereArgs ?? const []);
      }
      return (await database).query(table,
          where: clauses.isEmpty ? null : clauses.join(' AND '),
          whereArgs: args.isEmpty ? null : args,
          orderBy: orderBy,
          limit: limit);
    });
  }

  Future<int> count(String table, {String? where, List<Object?>? whereArgs}) {
    return _guard('count $table', () async {
      final r = await (await database).rawQuery(
          'SELECT COUNT(*) AS c FROM $table${where == null ? '' : ' WHERE $where'}',
          whereArgs);
      return Sqflite.firstIntValue(r) ?? 0;
    });
  }

  /// Runs [action] atomically; any thrown error rolls everything back.
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) {
    return _guard('transaction', () async => (await database).transaction(action));
  }

  // ------------------------------------------------------ BACKUP/RESTORE ---

  /// Copies the database file into [directoryPath]; returns the new file.
  Future<File> backupTo(String directoryPath) async {
    try {
      await (await database).execute('PRAGMA wal_checkpoint(FULL)');
      final stamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final target = p.join(directoryPath, 'pairbloom_backup_$stamp.db');
      return await File(await _dbPath).copy(target);
    } on FileSystemException catch (e) {
      throw AppDatabaseException('Backup failed: ${e.message}', e);
    }
  }

  /// Replaces the current database with a validated backup file.
  Future<void> restoreFrom(File backup) async {
    if (!await backup.exists()) {
      throw AppDatabaseException('The backup file could not be found.');
    }
    Database? probe;
    try {
      probe = await openDatabase(backup.path, readOnly: true);
      final integrity = await probe.rawQuery('PRAGMA integrity_check');
      final ok = integrity.isNotEmpty && integrity.first.values.first == 'ok';
      final hasTables = (await probe.rawQuery(
              "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('couple_profiles','app_settings')"))
          .length ==
          2;
      final version = Sqflite.firstIntValue(await probe.rawQuery('PRAGMA user_version')) ?? 0;
      if (!ok || !hasTables) {
        throw AppDatabaseException('This is not a valid PairBloom backup.');
      }
      if (version > DatabaseMigrations.currentVersion) {
        throw AppDatabaseException('This backup was made by a newer version of PairBloom.');
      }
    } on DatabaseException catch (e) {
      throw AppDatabaseException('This is not a valid PairBloom backup.', e);
    } finally {
      await probe?.close();
    }

    final path = await _dbPath;
    await close();
    final safety = File('$path.pre_restore');
    try {
      if (await File(path).exists()) await File(path).copy(safety.path);
      await backup.copy(path);
      await database; // reopen (runs migrations if the backup is older)
      if (await safety.exists()) await safety.delete();
    } catch (e) {
      // Roll back to the previous database if anything went wrong.
      await close();
      if (await safety.exists()) await safety.copy(path);
      throw AppDatabaseException('Restore failed. Your current data was kept.', e);
    }
  }

  /// Deletes all rows from every table in one transaction.
  Future<void> clearAllData() {
    return transaction((txn) async {
      for (final t in DatabaseMigrations.tableNames.reversed) {
        await txn.delete(t);
      }
      await txn.execute("DELETE FROM sqlite_sequence");
    });
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
