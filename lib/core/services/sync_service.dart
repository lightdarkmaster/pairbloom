import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' show Database;

import '../../repositories/repos.dart';
import '../database/database_helper.dart';
import '../database/database_migrations.dart';
import '../utilities/id_helper.dart';
import 'image_service.dart';

class SyncException implements Exception {
  SyncException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// This phone already has a different couple profile than the cloud.
class SyncConflictException extends SyncException {
  SyncConflictException() : super('This phone has a different couple profile than the cloud.');
}

class SyncReport {
  int uploaded = 0, downloaded = 0, deleted = 0, photosUp = 0, photosDown = 0, photoErrors = 0;
  String get summary =>
      '$uploaded sent • $downloaded received • $deleted removed'
      '${photosUp + photosDown > 0 ? ' • photos ↑$photosUp ↓$photosDown' : ''}'
      '${photoErrors > 0 ? ' • $photoErrors photo error(s)' : ''}';
}

/// Optional two-way sync between the local SQLite database and Firestore.
///
/// - Every synced row has a UUID `sync_id`, identical on both phones.
/// - Conflicts: the most recently updated version wins.
/// - Deletions travel as tombstones.
/// - The Private Vault and device settings are never uploaded.
/// - SQLite stays the source of truth: the app works fully offline.
class SyncService extends ChangeNotifier {
  SyncService._();
  static final SyncService instance = SyncService._();

  static const kAuto = 'sync_auto';
  static const kPhotos = 'sync_photos';
  static const kLocations = 'sync_locations';
  static const _kPull = 'sync_last_pull';
  static const _kPush = 'sync_last_push';
  static const _kRun = 'sync_last_run';
  static const _kUploaded = 'sync_uploaded';
  static const _photoKeys = {'partner1_photo_path', 'partner2_photo_path', 'photo_path'};

  bool available = false;
  String? initError;
  bool busy = false;
  bool autoSync = false;
  String? lastError;
  SyncReport? lastReport;
  DateTime? lastSync;

  Timer? _debounce;
  final _applied = <String>{};
  final _columnCache = <String, Set<String>>{};
  final _coupleSyncIds = <int, String?>{};
  String _imagesDir = '';

  FirebaseFirestore get _fs => FirebaseFirestore.instance;
  User? get user => available ? FirebaseAuth.instance.currentUser : null;
  bool get signedIn => user != null;

  // ------------------------------------------------------------ settings ---
  Future<bool> flag(String key, {bool def = false}) async {
    final v = await Repos.settings.get(key);
    return v == null ? def : v == '1';
  }

  Future<void> setFlag(String key, bool value) async {
    await Repos.settings.set(key, value ? '1' : '0');
    if (key == kAuto) autoSync = value;
    notifyListeners();
  }

  Future<DateTime?> _readTime(String key) async {
    final v = int.tryParse(await Repos.settings.get(key) ?? '');
    return v == null ? null : DateTime.fromMicrosecondsSinceEpoch(v, isUtc: true);
  }

  Future<void> _writeTime(String key, DateTime t) => Repos.settings.set(key, '${t.microsecondsSinceEpoch}');
  Future<void> _resetCursors() async {
    await Repos.settings.set(_kPull, '');
    await Repos.settings.set(_kPush, '');
    await Repos.settings.set(_kUploaded, '[]');
  }

  // ---------------------------------------------------------------- init ---
  /// Connects to Firebase. Fails softly if the project is not configured.
  Future<void> init() async {
    if (available) return;
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      available = true;
      initError = null;
    } catch (e) {
      available = false;
      initError = 'Firebase is not set up in this build yet. $e';
    }
    notifyListeners();
  }

  /// Called at app start: reconnects and syncs if auto-sync is on.
  Future<void> onAppStart() async {
    autoSync = await flag(kAuto);
    lastSync = DateTime.tryParse(await Repos.settings.get(_kRun) ?? '');
    if (!autoSync) return;
    await init();
    if (signedIn) await syncSafely();
  }

  /// Debounced: sync 20 s after the last local change.
  void scheduleSync() {
    if (!autoSync || !available || !signedIn) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 20), syncSafely);
  }

  Future<void> syncSafely() async {
    try {
      await sync();
    } catch (e) {
      lastError = e.toString();
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------- auth ---
  String _authMessage(FirebaseAuthException e) => switch (e.code) {
        'email-already-in-use' => 'That email already has an account. Use Sign in.',
        'wrong-password' || 'invalid-credential' || 'user-not-found' => 'Wrong email or password.',
        'weak-password' => 'Choose a stronger password (at least 6 characters).',
        'invalid-email' => 'That email address does not look right.',
        'network-request-failed' => 'No internet connection.',
        'too-many-requests' => 'Too many attempts. Try again later.',
        _ => e.message ?? 'Sign-in failed.',
      };

  Future<void> signIn(String email, String password) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email.trim(), password: password);
      await setFlag(kAuto, true);
    } on FirebaseAuthException catch (e) {
      throw SyncException(_authMessage(e));
    }
  }

  Future<void> register(String email, String password) async {
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email.trim(), password: password);
      await setFlag(kAuto, true);
    } on FirebaseAuthException catch (e) {
      throw SyncException(_authMessage(e));
    }
  }

  Future<void> signOut() async {
    _debounce?.cancel();
    await FirebaseAuth.instance.signOut();
    await _resetCursors();
    await setFlag(kAuto, false);
  }

  // ---------------------------------------------------------------- sync ---
  Future<SyncReport> sync() async {
    if (!available) throw SyncException('Firebase is not connected.');
    final u = user;
    if (u == null) throw SyncException('Sign in first.');
    if (busy) throw SyncException('A sync is already running.');
    busy = true;
    lastError = null;
    notifyListeners();

    final started = DateTime.now().toUtc();
    final report = SyncReport();
    try {
      _imagesDir = await ImageService().imagesDirPath();
      _applied.clear();
      _coupleSyncIds.clear();
      await _assignMissingIds();

      final tables = (await flag(kLocations))
          ? DatabaseMigrations.syncTables
          : DatabaseMigrations.syncTables.where((t) => t != 'locations').toList();

      await _checkCoupleMismatch(u.uid);

      final since = await _readTime(_kPull);
      var newest = since;
      for (final t in tables) {
        final n = await _pull(u.uid, t, since, report);
        if (n != null && (newest == null || n.isAfter(newest))) newest = n;
      }

      final lastPush = await _readTime(_kPush);
      for (final t in tables) {
        await _push(u.uid, t, lastPush, report);
      }
      await _pushTombstones(u.uid, tables);

      if (await flag(kPhotos)) await _syncPhotos(u.uid, report);

      if (newest != null) await _writeTime(_kPull, newest.subtract(const Duration(minutes: 2)));
      await _writeTime(_kPush, started);
      lastSync = DateTime.now();
      lastReport = report;
      await Repos.settings.set(_kRun, lastSync!.toIso8601String());
      return report;
    } on FirebaseException catch (e) {
      throw SyncException(switch (e.code) {
        'permission-denied' => 'The cloud refused access. Check your Firestore security rules.',
        'unavailable' => 'No internet connection.',
        _ => e.message ?? 'Sync failed (${e.code}).',
      });
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  // --------------------------------------------------------- local helpers --
  DateTime? _parseUtc(Object? v) => v is String ? DateTime.tryParse(v)?.toUtc() : null;
  String _utcIso(Object? v) => (_parseUtc(v) ?? DateTime.now().toUtc()).toIso8601String();

  Future<Set<String>> _columns(Database d, String table) async {
    final cached = _columnCache[table];
    if (cached != null) return cached;
    final rows = await d.rawQuery('PRAGMA table_info($table)');
    return _columnCache[table] = {for (final r in rows) r['name'] as String};
  }

  Future<void> _assignMissingIds() async {
    final d = await DatabaseHelper.instance.database;
    for (final t in DatabaseMigrations.syncTables) {
      final rows = await d.query(t, columns: ['id'], where: 'sync_id IS NULL');
      if (rows.isEmpty) continue;
      final batch = d.batch();
      for (final r in rows) {
        batch.update(t, {'sync_id': IdHelper.newSyncId()}, where: 'id = ?', whereArgs: [r['id']]);
      }
      await batch.commit(noResult: true);
    }
  }

  Future<String?> _coupleSyncId(Database d, int id) async {
    if (_coupleSyncIds.containsKey(id)) return _coupleSyncIds[id];
    final r = await d.query('couple_profiles', columns: ['sync_id'], where: 'id = ?', whereArgs: [id], limit: 1);
    return _coupleSyncIds[id] = r.isEmpty ? null : r.first['sync_id'] as String?;
  }

  Future<int?> _localCoupleId(Database d, String syncId) async {
    final r = await d.query('couple_profiles', columns: ['id'], where: 'sync_id = ?', whereArgs: [syncId], limit: 1);
    return r.isEmpty ? null : r.first['id'] as int;
  }

  /// If the cloud already holds a couple profile that is not this phone's one,
  /// the user must choose to adopt the cloud data.
  Future<void> _checkCoupleMismatch(String uid) async {
    final d = await DatabaseHelper.instance.database;
    final local = await d.query('couple_profiles', columns: ['sync_id'], orderBy: 'id ASC', limit: 1);
    if (local.isEmpty) return;
    final snap = await _fs
        .collection('users')
        .doc(uid)
        .collection('couple_profiles')
        .get(const GetOptions(source: Source.server));
    final remote = snap.docs.where((x) => x.data()['deleted'] != true).map((x) => x.id).toList();
    if (remote.isNotEmpty && !remote.contains(local.first['sync_id'])) throw SyncConflictException();
  }

  /// Replaces this phone's synced data (not the vault or settings) with the cloud copy.
  Future<SyncReport> replaceLocalWithCloud() async {
    final db = DatabaseHelper.instance;
    await db.transaction((txn) async {
      await txn.delete('memory_photos');
      for (final t in DatabaseMigrations.syncTables.reversed) {
        await txn.delete(t);
      }
      await txn.delete('sync_tombstones');
    });
    await _resetCursors();
    return sync();
  }

  // ---------------------------------------------------------------- pull ---
  Future<DateTime?> _pull(String uid, String table, DateTime? since, SyncReport r) async {
    Query<Map<String, dynamic>> q = _fs.collection('users').doc(uid).collection(table);
    if (since != null) q = q.where('_server', isGreaterThan: Timestamp.fromDate(since));
    final snap = await q.get(const GetOptions(source: Source.server));
    final d = await DatabaseHelper.instance.database;
    DateTime? newest;
    for (final doc in snap.docs) {
      final data = doc.data();
      final ts = data['_server'];
      if (ts is Timestamp) {
        final dt = ts.toDate().toUtc();
        if (newest == null || dt.isAfter(newest)) newest = dt;
      }
      await _applyRemote(d, table, doc.id, data, r);
    }
    return newest;
  }

  Future<void> _applyRemote(Database d, String table, String sid, Map<String, dynamic> data, SyncReport r) async {
    final remoteUpdated = _parseUtc(data['updated_at']) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    var existing = await d.query(table, where: 'sync_id = ?', whereArgs: [sid], limit: 1);
    final tomb = await d.query('sync_tombstones', where: 'table_name = ? AND sync_id = ?', whereArgs: [table, sid], limit: 1);

    if (data['deleted'] == true) {
      if (existing.isNotEmpty) {
        final localUpdated = _parseUtc(existing.first['updated_at']);
        if (localUpdated == null || !localUpdated.isAfter(remoteUpdated)) {
          await d.delete(table, where: 'sync_id = ?', whereArgs: [sid]); // photo rows cascade
          r.deleted++;
        } else {
          return; // edited here after it was deleted elsewhere: keep, it will be re-uploaded
        }
      }
      if (tomb.isNotEmpty) await d.delete('sync_tombstones', where: 'table_name = ? AND sync_id = ?', whereArgs: [table, sid]);
      _applied.add('$table:$sid');
      return;
    }

    if (tomb.isNotEmpty) {
      final td = _parseUtc(tomb.first['deleted_at']);
      if (td != null && td.isAfter(remoteUpdated)) return; // deleted here after the remote edit
      await d.delete('sync_tombstones', where: 'table_name = ? AND sync_id = ?', whereArgs: [table, sid]);
    }

    final row = await _toLocalRow(d, table, sid, data);
    if (row == null) return;

    // The same challenge completed on both phones before syncing: adopt one record.
    if (existing.isEmpty && table == 'couple_challenges') {
      existing = await d.query(table,
          where: 'couple_id = ? AND challenge_key = ?', whereArgs: [row['couple_id'], row['challenge_key']], limit: 1);
    }

    int localId;
    if (existing.isEmpty) {
      localId = await d.insert(table, row);
      r.downloaded++;
    } else {
      final localUpdated = _parseUtc(existing.first['updated_at']);
      localId = existing.first['id'] as int;
      if (localUpdated != null && !remoteUpdated.isAfter(localUpdated)) return; // local is newer or equal
      await d.update(table, row, where: 'id = ?', whereArgs: [localId]);
      r.downloaded++;
    }
    _applied.add('$table:$sid');

    if (table == 'memories' && data['photos'] is List) {
      await d.delete('memory_photos', where: 'memory_id = ?', whereArgs: [localId]);
      final now = DateTime.now().toUtc().toIso8601String();
      for (final name in (data['photos'] as List).whereType<String>()) {
        await d.insert('memory_photos', {
          'memory_id': localId,
          'file_path': p.join(_imagesDir, name),
          'created_at': now,
          'updated_at': now,
        });
      }
    }
  }

  Future<Map<String, Object?>?> _toLocalRow(Database d, String table, String sid, Map<String, dynamic> data) async {
    final cols = await _columns(d, table);
    final row = <String, Object?>{};
    data.forEach((k, v) {
      if (k.startsWith('_') || k == 'deleted' || k == 'photos' || k == 'couple_sync_id') return;
      if (!cols.contains(k) || k == 'id' || k == 'sync_id') return;
      row[k] = (_photoKeys.contains(k) && v is String && v.isNotEmpty) ? p.join(_imagesDir, v) : v;
    });
    row['sync_id'] = sid;
    final cs = data['couple_sync_id'];
    if (cs is String) {
      final id = await _localCoupleId(d, cs);
      if (id == null) return null; // parent not here yet; retried on the next sync
      row['couple_id'] = id;
    }
    return row;
  }

  // ---------------------------------------------------------------- push ---
  Future<Map<int, List<String>>> _photosByMemory(Database d) async {
    final out = <int, List<String>>{};
    for (final r in await d.query('memory_photos', orderBy: 'id ASC')) {
      out.putIfAbsent(r['memory_id'] as int, () => []).add(p.basename(r['file_path'] as String));
    }
    return out;
  }

  Future<void> _push(String uid, String table, DateTime? lastPush, SyncReport r) async {
    final d = await DatabaseHelper.instance.database;
    final rows = await d.query(table);
    final photos = table == 'memories' ? await _photosByMemory(d) : const <int, List<String>>{};
    final col = _fs.collection('users').doc(uid).collection(table);
    var batch = _fs.batch();
    var pending = 0;

    for (final row in rows) {
      final sid = row['sync_id'] as String?;
      if (sid == null || _applied.contains('$table:$sid')) continue;
      final updated = _parseUtc(row['updated_at']);
      if (lastPush != null && updated != null && !updated.isAfter(lastPush)) continue;

      final doc = <String, Object?>{};
      row.forEach((k, v) {
        if (k == 'id' || k == 'sync_id' || k == 'couple_id') return;
        doc[k] = (_photoKeys.contains(k) && v is String && v.isNotEmpty) ? p.basename(v) : v;
      });
      doc['created_at'] = _utcIso(row['created_at']);
      doc['updated_at'] = _utcIso(row['updated_at']);
      doc['deleted'] = false;
      doc['_server'] = FieldValue.serverTimestamp();
      final cid = row['couple_id'];
      if (cid is int) doc['couple_sync_id'] = await _coupleSyncId(d, cid);
      if (table == 'memories') doc['photos'] = photos[row['id']] ?? <String>[];

      batch.set(col.doc(sid), doc);
      r.uploaded++;
      if (++pending == 400) {
        await batch.commit();
        batch = _fs.batch();
        pending = 0;
      }
    }
    if (pending > 0) await batch.commit();
  }

  Future<void> _pushTombstones(String uid, List<String> tables) async {
    final d = await DatabaseHelper.instance.database;
    final rows = await d.query('sync_tombstones');
    var batch = _fs.batch();
    var pending = 0;
    final sent = <Map<String, Object?>>[];
    for (final t in rows) {
      final table = t['table_name'] as String;
      if (!tables.contains(table)) continue;
      batch.set(_fs.collection('users').doc(uid).collection(table).doc(t['sync_id'] as String), {
        'deleted': true,
        'updated_at': _utcIso(t['deleted_at']),
        '_server': FieldValue.serverTimestamp(),
      });
      sent.add(t);
      if (++pending == 400) {
        await batch.commit();
        batch = _fs.batch();
        pending = 0;
      }
    }
    if (pending > 0) await batch.commit();
    for (final t in sent) {
      await d.delete('sync_tombstones', where: 'id = ?', whereArgs: [t['id']]);
    }
  }

  // -------------------------------------------------------------- photos ---
  Future<void> _syncPhotos(String uid, SyncReport r) async {
    final d = await DatabaseHelper.instance.database;
    final names = <String>{};
    for (final x in await d.query('memory_photos', columns: ['file_path'])) {
      names.add(p.basename(x['file_path'] as String));
    }
    for (final x in await d.query('couple_profiles', columns: ['partner1_photo_path', 'partner2_photo_path'])) {
      for (final v in x.values) {
        if (v is String && v.isNotEmpty) names.add(p.basename(v));
      }
    }
    for (final x in await d.query('gift_wishlist', columns: ['photo_path'], where: 'photo_path IS NOT NULL')) {
      names.add(p.basename(x['photo_path'] as String));
    }

    Set<String> uploaded;
    try {
      uploaded = (jsonDecode(await Repos.settings.get(_kUploaded) ?? '[]') as List).cast<String>().toSet();
    } catch (_) {
      uploaded = {};
    }

    for (final n in names) {
      final file = File(p.join(_imagesDir, n));
      final ref = FirebaseStorage.instance.ref('users/$uid/photos/$n');
      try {
        if (await file.exists()) {
          if (!uploaded.contains(n)) {
            await ref.putFile(file);
            uploaded.add(n);
            r.photosUp++;
          }
        } else {
          await ref.writeToFile(file);
          uploaded.add(n);
          r.photosDown++;
        }
      } catch (_) {
        r.photoErrors++; // not uploaded yet, no Storage access, or no internet
      }
    }
    await Repos.settings.set(_kUploaded, jsonEncode(uploaded.toList()));
  }

  // -------------------------------------------------------- delete cloud ---
  Future<void> deleteCloudData() async {
    final u = user;
    if (u == null) throw SyncException('Sign in first.');
    try {
      for (final t in DatabaseMigrations.syncTables) {
        final col = _fs.collection('users').doc(u.uid).collection(t);
        while (true) {
          final snap = await col.limit(300).get(const GetOptions(source: Source.server));
          if (snap.docs.isEmpty) break;
          final batch = _fs.batch();
          for (final doc in snap.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit();
        }
      }
      try {
        final list = await FirebaseStorage.instance.ref('users/${u.uid}/photos').listAll();
        for (final item in list.items) {
          await item.delete();
        }
      } catch (_) {}
      await _resetCursors();
    } on FirebaseException catch (e) {
      throw SyncException(e.message ?? 'Could not delete cloud data.');
    }
  }
}
