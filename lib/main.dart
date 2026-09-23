import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:masiro/data/database/migration/migration.dart';
import 'package:masiro/data/repository/preferences_repository.dart';
import 'package:masiro/di/get_it.dart';
import 'package:masiro/misc/platform.dart';
import 'package:masiro/ui/app.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (isDesktop) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(title: '真白萌', center: true);
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  await setupGetIt();

  await PreferencesRepository.init();

  await performMigrationIfNeeded();

  runApp(const App());
}
