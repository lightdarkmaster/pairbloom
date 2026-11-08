# PairBloom – Flutter offline couples companion

PairBloom is an offline-first Flutter starter app using SQLite (`sqflite`).

## Included in this MVP
- Couple profile and relationship start date
- Days-together dashboard and local record counters
- Memories: create, read, update, delete
- Important dates: create, read, update, delete
- Love notes: create and read, with delete
- Bucket list: create, read, mark complete/incomplete, delete
- Shared expenses: create, read, delete
- SQLite database stored locally on the device
- Pastel rose Material 3 UI

## Run it

1. Install Flutter and Android Studio (or another Flutter-supported IDE).
2. Extract this archive.
3. From the `pairbloom_flutter` directory, run:

   ```bash
   flutter create .
   flutter pub get
   flutter run
   ```

   If `flutter create .` asks about overwriting files, preserve the supplied `pubspec.yaml` and `lib/main.dart`.

4. For Android, use a connected device or start an emulator.

## Database

The database file is named `pairbloom.db`. It is created automatically on first launch.
All app records are stored locally. No network service is used.

## Notes / next development steps

This is a runnable MVP foundation, not the full feature list from the product brief. Recommended next additions:
- Local image attachment and gallery for memories
- Local notification scheduling for important dates
- Edit actions for love notes, bucket-list items, and expenses
- Database export/import backup and restore
- Private vault with encryption and biometric lock
- Search, filtering, analytics, recurring events, and automated tests

The app does not synchronize data between two phones. Cross-device sharing would require an optional sync mechanism.
