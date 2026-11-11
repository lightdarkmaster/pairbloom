import '../models/location_entry.dart';
import 'base_repository.dart';

class LocationRepository extends BaseRepository<LocationEntry> {
  LocationRepository(super.db);
  @override
  String get table => 'locations';
  @override
  List<String> get searchColumns => ['label'];
  @override
  LocationEntry fromMap(Map<String, Object?> m) => LocationEntry.fromMap(m);

  @override
  void validate(LocationEntry e) {
    if (e.latitude < -90 || e.latitude > 90) throw ValidationException('Latitude must be between -90 and 90.');
    if (e.longitude < -180 || e.longitude > 180) throw ValidationException('Longitude must be between -180 and 180.');
    if (e.isPlace && (e.label?.trim().isEmpty ?? true)) throw ValidationException('Give this place a name.');
  }

  /// Most recent position recorded for a partner (1 or 2).
  Future<LocationEntry?> latest(int coupleId, int owner) async {
    final l = await getAll(
        where: 'couple_id = ? AND owner = ? AND is_place = 0',
        whereArgs: [coupleId, owner],
        orderBy: 'recorded_at DESC, id DESC',
        limit: 1);
    return l.isEmpty ? null : l.first;
  }

  Future<List<LocationEntry>> history(int coupleId, {int limit = 12}) => getAll(
      where: 'couple_id = ? AND is_place = 0',
      whereArgs: [coupleId],
      orderBy: 'recorded_at DESC, id DESC',
      limit: limit);

  Future<List<LocationEntry>> places(int coupleId) => getAll(
      where: 'couple_id = ? AND is_place = 1', whereArgs: [coupleId], orderBy: 'label COLLATE NOCASE ASC');
}
