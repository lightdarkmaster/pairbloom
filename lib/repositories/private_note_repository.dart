import 'dart:convert';

import '../core/database/database_helper.dart';
import '../core/services/vault_service.dart';
import '../models/private_note.dart';
import 'base_repository.dart';

/// CRUD for the `private_notes` table. Title and content are encrypted together
/// into `encrypted_content`; the plain `title` column only holds a generic label.
class PrivateNoteRepository {
  PrivateNoteRepository(this.db, this.vault);
  final DatabaseHelper db;
  final VaultService vault;
  static const _table = 'private_notes';

  void _validate(String title, String content) {
    if (title.trim().isEmpty) throw ValidationException('Please enter a title.');
    if (content.trim().isEmpty) throw ValidationException('Please write something first.');
  }

  Future<PrivateNote> _decode(Map<String, Object?> r) async {
    final created = DateTime.parse(r['created_at'] as String);
    final updated = DateTime.parse(r['updated_at'] as String);
    try {
      final json = jsonDecode(await vault.decrypt(r['encrypted_content'] as String, r['iv'] as String))
          as Map<String, dynamic>;
      return PrivateNote(
          id: r['id'] as int,
          coupleId: r['couple_id'] as int,
          type: r['note_type'] as String,
          title: json['t'] as String,
          content: json['c'] as String,
          createdAt: created,
          updatedAt: updated);
    } catch (_) {
      return PrivateNote(
          id: r['id'] as int,
          coupleId: r['couple_id'] as int,
          type: r['note_type'] as String,
          title: 'Unreadable entry',
          content: 'This entry could not be decrypted. Its encryption key is not available on this device.',
          createdAt: created,
          updatedAt: updated,
          unreadable: true);
    }
  }

  Future<List<PrivateNote>> getAll() async {
    final rows = await db.getAll(_table, orderBy: 'updated_at DESC');
    return [for (final r in rows) await _decode(r)];
  }

  Future<PrivateNote?> getById(int id) async {
    final r = await db.getById(_table, id);
    return r == null ? null : _decode(r);
  }

  Future<List<PrivateNote>> search(String query) async {
    final q = query.trim().toLowerCase();
    final all = await getAll();
    return q.isEmpty ? all : all.where((n) => '${n.title} ${n.content}'.toLowerCase().contains(q)).toList();
  }

  Future<Map<String, Object?>> _row(int coupleId, String type, String title, String content) async {
    final e = await vault.encrypt(jsonEncode({'t': title.trim(), 'c': content}));
    return {
      'couple_id': coupleId,
      'title': type == 'letter' ? 'Private letter' : 'Private note',
      'encrypted_content': e.cipher,
      'iv': e.iv,
      'note_type': type,
    };
  }

  Future<int> insert({required int coupleId, required String type, required String title, required String content}) async {
    _validate(title, content);
    return db.insert(_table, await _row(coupleId, type, title, content));
  }

  Future<int> update(
      {required int id, required int coupleId, required String type, required String title, required String content}) async {
    _validate(title, content);
    return db.update(_table, id, await _row(coupleId, type, title, content));
  }

  Future<int> delete(int id) => db.delete(_table, id);

  Future<void> deleteAll() => db.transaction((txn) async {
        await txn.delete(_table);
      });
}
