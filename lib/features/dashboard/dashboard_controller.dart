import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utilities/date_helper.dart';
import '../../models/couple_profile.dart';
import '../../models/important_date.dart';
import '../../models/memory.dart';
import '../../repositories/couple_profile_repository.dart';
import '../../repositories/important_date_repository.dart';
import '../../repositories/memory_repository.dart';

class Milestone {
  Milestone(this.label, this.date, this.achieved);
  final String label;
  final DateTime date;
  final bool achieved;
}

/// Loads and derives everything shown on the Home dashboard from SQLite.
class DashboardController extends ChangeNotifier {
  DashboardController(this._profiles, this._memories, this._dates);
  final CoupleProfileRepository _profiles;
  final MemoryRepository _memories;
  final ImportantDateRepository _dates;

  bool loading = true;
  String? error;
  CoupleProfile? profile;
  List<Memory> recentMemories = [];
  List<ImportantDate> todaysReminders = [];
  List<UpcomingEvent> upcoming = [];

  static const _milestoneDays = [100, 200, 300, 365, 500, 730, 1000, 1500, 1825, 2000, 3000, 3650];

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      profile = await _profiles.getActive();
      final results = await Future.wait([
        _memories.recent(limit: 6),
        _dates.forDay(DateTime.now()),
        _dates.upcoming(limit: 3),
      ]);
      recentMemories = results[0] as List<Memory>;
      todaysReminders = results[1] as List<ImportantDate>;
      upcoming = results[2] as List<UpcomingEvent>;
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }

  int get daysTogether {
    final p = profile;
    if (p == null) return 0;
    final d = DateHelper.daysBetween(p.relationshipStartDate, DateTime.now());
    return d < 0 ? 0 : d;
  }

  DateTime? get nextAnniversary {
    final p = profile;
    return p == null ? null : DateHelper.nextOccurrence(p.effectiveAnniversary, DateTime.now());
  }

  int? get daysToAnniversary {
    final n = nextAnniversary;
    return n == null ? null : DateHelper.daysBetween(DateTime.now(), n);
  }

  /// Which anniversary is coming (e.g. 3 = third anniversary).
  int? get anniversaryYear {
    final p = profile;
    final n = nextAnniversary;
    return (p == null || n == null) ? null : n.year - p.effectiveAnniversary.year;
  }

  /// Last achieved milestone plus the next three.
  List<Milestone> get milestones {
    final p = profile;
    if (p == null) return const [];
    final today = DateHelper.dateOnly(DateTime.now());
    final all = [
      for (final d in _milestoneDays)
        Milestone('$d days together', p.relationshipStartDate.add(Duration(days: d)),
            !DateHelper.dateOnly(p.relationshipStartDate.add(Duration(days: d))).isAfter(today)),
    ];
    final achieved = all.where((m) => m.achieved).toList();
    final next = all.where((m) => !m.achieved).take(3).toList();
    return [if (achieved.isNotEmpty) achieved.last, ...next];
  }

  String get dailyQuote => LoveQuotes.forDate(DateTime.now());
}
