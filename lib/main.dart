import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/database/database_helper.dart';
import 'core/services/image_service.dart';
import 'core/theme/theme_controller.dart';
import 'features/dashboard/dashboard_controller.dart';
import 'features/profiles/profile_controller.dart';
import 'repositories/couple_profile_repository.dart';
import 'repositories/important_date_repository.dart';
import 'repositories/memory_repository.dart';
import 'repositories/settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Open (and migrate) the database before the first frame.
  final db = DatabaseHelper.instance;
  await db.database;

  final settingsRepo = SettingsRepository(db);
  final profileRepo = CoupleProfileRepository(db);
  final memoryRepo = MemoryRepository(db);
  final dateRepo = ImportantDateRepository(db);

  final theme = ThemeController(settingsRepo);
  await theme.load();

  runApp(MultiProvider(
    providers: [
      Provider<DatabaseHelper>.value(value: db),
      Provider<ImageService>(create: (_) => ImageService()),
      Provider<SettingsRepository>.value(value: settingsRepo),
      Provider<CoupleProfileRepository>.value(value: profileRepo),
      Provider<MemoryRepository>.value(value: memoryRepo),
      Provider<ImportantDateRepository>.value(value: dateRepo),
      ChangeNotifierProvider<ThemeController>.value(value: theme),
      ChangeNotifierProvider(create: (_) => ProfileController(profileRepo)..load()),
      ChangeNotifierProvider(create: (_) => DashboardController(profileRepo, memoryRepo, dateRepo)..load()),
    ],
    child: const PairBloomApp(),
  ));
}
