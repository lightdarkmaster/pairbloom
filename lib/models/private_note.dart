/// A decrypted vault entry. Title and content only exist in memory while the
/// vault is unlocked; SQLite stores them encrypted.
class PrivateNote {
  PrivateNote({
    this.id,
    required this.coupleId,
    required this.type,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.unreadable = false,
  });

  final int? id;
  final int coupleId;
  final String type; // 'note' | 'letter'
  final String title, content;
  final DateTime createdAt, updatedAt;
  final bool unreadable;

  bool get isLetter => type == 'letter';
  String get typeLabel => isLetter ? 'Private Letter' : 'Private Note';
}
