import '../core/database/database_helper.dart';
import '../models/couple_profile.dart';
import 'base_repository.dart';

class CoupleProfileRepository extends BaseRepository<CoupleProfile> {
  CoupleProfileRepository(DatabaseHelper db) : super(db);

  @override
  String get table => 'couple_profiles';
  @override
  List<String> get searchColumns =>
      ['partner1_name', 'partner2_name', 'partner1_nickname', 'partner2_nickname'];
  @override
  CoupleProfile fromMap(Map<String, Object?> map) => CoupleProfile.fromMap(map);

  @override
  void validate(CoupleProfile p) {
    if (p.partner1Name.trim().isEmpty || p.partner2Name.trim().isEmpty) {
      throw ValidationException('Both partner names are required.');
    }
    if (p.relationshipStartDate.isAfter(DateTime.now())) {
      throw ValidationException('The relationship start date cannot be in the future.');
    }
  }

  /// PairBloom is a single-couple app: the first profile is the active one.
  Future<CoupleProfile?> getActive() async {
    final list = await getAll(orderBy: 'id ASC', limit: 1);
    return list.isEmpty ? null : list.first;
  }
}
