import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/database/database_helper.dart';
import 'core/services/image_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/reminder_scheduler.dart';
import 'core/services/sync_service.dart';
import 'core/theme/theme_controller.dart';
import 'features/dashboard/dashboard_controller.dart';
import 'features/profiles/profile_controller.dart';
import 'features/vault/lock_controller.dart';
import 'repositories/repos.dart';
import 'repositories/couple_profile_repository.dart';
import 'repositories/important_date_repository.dart';
import 'repositories/memory_repository.dart';
import 'repositories/settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final db = DatabaseHelper.instance;
    await db.database;

    final settingsRepo = SettingsRepository(db);
    final profileRepo = CoupleProfileRepository(db);
    final memoryRepo = MemoryRepository(db);
    final dateRepo = ImportantDateRepository(db);

    final theme = ThemeController(settingsRepo);
    await theme.load();

    final lock = LockController(Repos.vault);
    await lock.load();

    // Notifications never block startup; reminders are rebuilt in the background.
    await NotificationService.instance.init();
    unawaited(ReminderScheduler.rescheduleAll());

    // Optional cloud sync: only active if the user turned it on.
    db.onDataChanged = SyncService.instance.scheduleSync;
    unawaited(SyncService.instance.onAppStart());

    runApp(MultiProvider(
      providers: [
        Provider<DatabaseHelper>.value(value: db),
        Provider<ImageService>(create: (_) => ImageService()),
        Provider<SettingsRepository>.value(value: settingsRepo),
        Provider<CoupleProfileRepository>.value(value: profileRepo),
        Provider<MemoryRepository>.value(value: memoryRepo),
        Provider<ImportantDateRepository>.value(value: dateRepo),
        ChangeNotifierProvider<ThemeController>.value(value: theme),
        ChangeNotifierProvider<LockController>.value(value: lock),
        ChangeNotifierProvider(create: (_) => ProfileController(profileRepo)..load()),
        ChangeNotifierProvider(
            create: (_) => DashboardController(profileRepo, memoryRepo, dateRepo)..load()),
      ],
      child: const PairBloomApp(),
    ));
  } catch (e, st) {
    debugPrint('STARTUP ERROR: $e\n$st');
    runApp(MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(child: Text('PairBloom failed to start:\n\n$e\n\n$st')),
          ),
        ),
      ),
    ));
  }
}
