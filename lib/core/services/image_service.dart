import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Copies picked images into app-private storage and returns their paths.
/// Only paths are stored in SQLite, never image bytes.
class ImageService {
  final _picker = ImagePicker();

  Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'pairbloom_images'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<String> imagesDirPath() async => (await _dir()).path;

  Future<String> _store(XFile picked) async {
    final dir = await _dir();
    final ext = p.extension(picked.path).isEmpty ? '.jpg' : p.extension(picked.path);
    final name = '${DateTime.now().microsecondsSinceEpoch}$ext';
    final saved = await File(picked.path).copy(p.join(dir.path, name));
    return saved.path;
  }

  /// Returns the stored file path, or null if the user cancelled.
  Future<String?> pickFromGallery() async {
    final x = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    return x == null ? null : _store(x);
  }

  Future<String?> pickFromCamera() async {
    final x = await _picker.pickImage(source: ImageSource.camera, maxWidth: 1600, imageQuality: 85);
    return x == null ? null : _store(x);
  }

  Future<List<String>> pickMultiple() async {
    final xs = await _picker.pickMultiImage(maxWidth: 1600, imageQuality: 85);
    return [for (final x in xs) await _store(x)];
  }

  Future<void> delete(String? path) async {
    if (path == null) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } on FileSystemException {
      // A missing/locked file must never block a record operation.
    }
  }
}
