import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'models.dart';
import 'email_service.dart';
import 'screens/config_screen.dart';
import 'screens/home_screen.dart';

const String emailPollTask = 'emailPollTask';

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    await NotificationService.initialize();
    final config = await AppState.loadConfig();
    if (config == null) {
      return Future.value(true);
    }

    await BackgroundEmailPoller.poll(config);
    return Future.value(true);
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize();
  final appState = await AppState.load();

  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  await Workmanager().registerPeriodicTask(
    'email_polling',
    emailPollTask,
    frequency: const Duration(minutes: 15),
    initialDelay: const Duration(seconds: 10),
    constraints: const Constraints(networkType: NetworkType.connected),
  );

  runApp(ChangeNotifierProvider(
    create: (_) => appState,
    child: const MonitoringByEmailApp(),
  ));
}

class MonitoringByEmailApp extends StatelessWidget {
  const MonitoringByEmailApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MonitoringByEmail',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo)),
      home: const HomeScreen(),
      routes: {
        '/config': (_) => const ConfigScreen(),
      },
    );
  }
}
