import '../repositories/base_repository.dart';

/// A saved coordinate: a partner's shared position, or a named saved place.
class LocationEntry implements DbModel {
  LocationEntry({
    this.id,
    required this.coupleId,
    this.owner = 0,
    this.label,
    required this.latitude,
    required this.longitude,
    this.accuracyM,
    this.source = 'manual',
    this.isPlace = false,
    required this.recordedAt,
  });

  @override
  final int? id;
  final int coupleId;

  /// 1 = Partner 1, 2 = Partner 2, 0 = shared saved place.
  final int owner;
  final String? label;
  final double latitude, longitude;
  final double? accuracyM;
  final String source; // 'gps' | 'code' | 'manual'
  final bool isPlace;
  final DateTime recordedAt;

  factory LocationEntry.fromMap(Map<String, Object?> m) => LocationEntry(
        id: m['id'] as int?,
        coupleId: m['couple_id'] as int,
        owner: m['owner'] as int,
        label: m['label'] as String?,
        latitude: (m['latitude'] as num).toDouble(),
        longitude: (m['longitude'] as num).toDouble(),
        accuracyM: (m['accuracy_m'] as num?)?.toDouble(),
        source: m['source'] as String,
        isPlace: m['is_place'] == 1,
        recordedAt: DateTime.parse(m['recorded_at'] as String).toLocal(),
      );

  @override
  Map<String, Object?> toMap() => {
        'id': id,
        'couple_id': coupleId,
        'owner': owner,
        'label': (label?.trim().isEmpty ?? true) ? null : label!.trim(),
        'latitude': latitude,
        'longitude': longitude,
        'accuracy_m': accuracyM,
        'source': source,
        'is_place': isPlace ? 1 : 0,
        'recorded_at': recordedAt.toUtc().toIso8601String(),
      };
}
