import 'package:flutter/foundation.dart';

import '../../models/couple_profile.dart';
import '../../repositories/couple_profile_repository.dart';

class ProfileController extends ChangeNotifier {
  ProfileController(this._repo);
  final CoupleProfileRepository _repo;

  CoupleProfile? profile;
  bool loading = true;
  String? error;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      profile = await _repo.getActive();
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }

  /// Creates the profile on first save, otherwise updates it.
  Future<void> save(CoupleProfile p) async {
    if (p.id == null) {
      await _repo.insert(p);
    } else {
      await _repo.update(p);
    }
    await load();
  }
}
