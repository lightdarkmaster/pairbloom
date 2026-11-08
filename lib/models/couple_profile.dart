import '../core/utilities/date_helper.dart';
import '../repositories/base_repository.dart';

class CoupleProfile implements DbModel {
  CoupleProfile({
    this.id,
    required this.partner1Name,
    this.partner1Nickname,
    this.partner1PhotoPath,
    this.partner1Bio,
    required this.partner2Name,
    this.partner2Nickname,
    this.partner2PhotoPath,
    this.partner2Bio,
    required this.relationshipStartDate,
    this.anniversaryDate,
    this.relationshipStatus = 'In a Relationship',
  });

  @override
  final int? id;
  final String partner1Name;
  final String? partner1Nickname;
  final String? partner1PhotoPath;
  final String? partner1Bio;
  final String partner2Name;
  final String? partner2Nickname;
  final String? partner2PhotoPath;
  final String? partner2Bio;
  final DateTime relationshipStartDate;
  final DateTime? anniversaryDate;
  final String relationshipStatus;

  /// Anniversary falls back to the relationship start date when not set.
  DateTime get effectiveAnniversary => anniversaryDate ?? relationshipStartDate;

  static String? _clean(String? s) {
    final t = s?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  factory CoupleProfile.fromMap(Map<String, Object?> m) => CoupleProfile(
        id: m['id'] as int?,
        partner1Name: m['partner1_name'] as String,
        partner1Nickname: m['partner1_nickname'] as String?,
        partner1PhotoPath: m['partner1_photo_path'] as String?,
        partner1Bio: m['partner1_bio'] as String?,
        partner2Name: m['partner2_name'] as String,
        partner2Nickname: m['partner2_nickname'] as String?,
        partner2PhotoPath: m['partner2_photo_path'] as String?,
        partner2Bio: m['partner2_bio'] as String?,
        relationshipStartDate: DateTime.parse(m['relationship_start_date'] as String),
        anniversaryDate: DateHelper.parse(m['anniversary_date'] as String?),
        relationshipStatus: m['relationship_status'] as String,
      );

  @override
  Map<String, Object?> toMap() => {
        'id': id,
        'partner1_name': partner1Name.trim(),
        'partner1_nickname': _clean(partner1Nickname),
        'partner1_photo_path': partner1PhotoPath,
        'partner1_bio': _clean(partner1Bio),
        'partner2_name': partner2Name.trim(),
        'partner2_nickname': _clean(partner2Nickname),
        'partner2_photo_path': partner2PhotoPath,
        'partner2_bio': _clean(partner2Bio),
        'relationship_start_date': DateHelper.toDb(relationshipStartDate),
        'anniversary_date':
            anniversaryDate == null ? null : DateHelper.toDb(anniversaryDate!),
        'relationship_status': relationshipStatus,
      };
}
