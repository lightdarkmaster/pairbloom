import 'package:flutter/foundation.dart';

import '../../core/services/image_service.dart';
import '../../models/memory.dart';
import '../../repositories/memory_repository.dart';

/// Holds the memory list state (search, filters) and all memory operations.
class MemoryController extends ChangeNotifier {
  MemoryController(this._repo, this._images, {this.onChanged});
  final MemoryRepository _repo;
  final ImageService _images;

  /// Called after any change so other screens (dashboard) can refresh.
  final VoidCallback? onChanged;

  List<Memory> items = [];
  bool loading = true;
  String? error;
  String query = '';
  String? category;
  bool favoritesOnly = false;

  int get photoCount => items.fold(0, (s, m) => s + m.photoPaths.length);

  Future<void> load() async {
    try {
      items = await _repo.filter(query: query, category: category, favoritesOnly: favoritesOnly);
      error = null;
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }

  void setQuery(String q) {
    query = q.trim();
    load();
  }

  void setCategory(String? c) {
    category = c;
    load();
  }

  void toggleFavoritesOnly() {
    favoritesOnly = !favoritesOnly;
    load();
  }

  /// Inserts or updates; photos removed during editing are deleted from disk
  /// only after the database change succeeds.
  Future<void> save(Memory m, {List<String> removedPhotos = const []}) async {
    if (m.id == null) {
      await _repo.insert(m);
    } else {
      await _repo.update(m);
    }
    for (final p in removedPhotos) {
      await _images.delete(p);
    }
    await load();
    onChanged?.call();
  }

  Future<void> delete(Memory m) async {
    final paths = List<String>.from(m.photoPaths);
    await _repo.delete(m.id!); // photo rows cascade
    for (final p in paths) {
      await _images.delete(p);
    }
    await load();
    onChanged?.call();
  }

  Future<void> toggleFavorite(Memory m) async {
    await _repo.setFavorite(m.id!, !m.isFavorite);
    await load();
    onChanged?.call();
  }
}
