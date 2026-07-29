import 'package:flutter/material.dart';
import 'config/app_config.dart';
import 'core/app_theme.dart';
import 'core/local_db.dart';
import 'pages/dashboard_page.dart';
import 'pages/login_page.dart';
import 'services/gps_service.dart';
import 'services/auto_logout_service.dart';
import 'services/session_service.dart';
import 'services/sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalDb.instance.database;

  SessionService.instance.registerSessionExpiredHandler(_handleExpiredSession);

  var loggedIn = await SessionService.instance.isLoggedIn();
  if (loggedIn && AutoLogoutService.instance.isAutoLogoutTimeNow()) {
    await SessionService.instance.clear();
    loggedIn = false;
  }

  if (loggedIn) {
    SyncService.instance.startAutoSync();
    await GpsService.instance.startTracking();
    AutoLogoutService.instance.start();

    // A server-side expired token may be detected while startup services run.
    loggedIn = await SessionService.instance.isLoggedIn();
  }

  runApp(AgraniApp(loggedIn: loggedIn));
}

Future<void> _handleExpiredSession() async {
  AutoLogoutService.instance.stop();

  void redirectToLogin() {
    final nav = AutoLogoutService.navigatorKey.currentState;
    if (nav == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => redirectToLogin());
      return;
    }
    nav.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  // Redirect immediately; service shutdown must not hold the user on a secured
  // screen after the local session has already been cleared.
  redirectToLogin();

  await SyncService.instance.stopAutoSync();
  await GpsService.instance.stopTracking(saveLastPoint: false);
}

class AgraniApp extends StatefulWidget {
  final bool loggedIn;
  const AgraniApp({super.key, required this.loggedIn});

  @override
  State<AgraniApp> createState() => _AgraniAppState();
}

class _AgraniAppState extends State<AgraniApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AutoLogoutService.instance.checkNow();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppConfig.appName,
      theme: AppTheme.light(),
      navigatorKey: AutoLogoutService.navigatorKey,
      home: widget.loggedIn ? const DashboardPage() : const LoginPage(),
    );
  }
}
