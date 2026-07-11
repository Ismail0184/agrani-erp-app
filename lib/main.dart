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
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalDb.instance.database;

  var loggedIn = await SessionService.instance.isLoggedIn();
  if (loggedIn && AutoLogoutService.instance.isAutoLogoutTimeNow()) {
    final loginAfterAutoLogout = await SessionService.instance.isLoginAfterAutoLogout();
    if (!loginAfterAutoLogout) {
      await AuthService.instance.logout(autoLogout: true);
      loggedIn = false;
    }
  }

  if (loggedIn) {
    SyncService.instance.startAutoSync();
    if (AutoLogoutService.instance.canRecordAttendanceAndGpsNow()) {
      await GpsService.instance.startTracking();
      AutoLogoutService.instance.start();
    }
  }

  runApp(AgraniApp(loggedIn: loggedIn));
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
