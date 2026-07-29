import 'dart:async';

import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'session_service.dart';

class AutoLogoutService {
  AutoLogoutService._();
  static final AutoLogoutService instance = AutoLogoutService._();

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static const int autoLogoutHour = 22; // 10:00 PM Bangladesh time
  static const Duration bangladeshOffset = Duration(hours: 6);

  Timer? _timer;
  bool _processing = false;

  void start() {
    stop();
    _timer = Timer(_delayUntilToday10PmBangladesh(), checkNow);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  DateTime bangladeshNow() {
    final bd = DateTime.now().toUtc().add(bangladeshOffset);
    return DateTime(bd.year, bd.month, bd.day, bd.hour, bd.minute, bd.second, bd.millisecond);
  }

  bool isAutoLogoutTimeNow() {
    final now = bangladeshNow();
    return now.hour >= autoLogoutHour;
  }

  bool canRecordAttendanceAndGpsNow() => !isAutoLogoutTimeNow();

  Duration _delayUntilToday10PmBangladesh() {
    final now = bangladeshNow();
    final target = DateTime(now.year, now.month, now.day, autoLogoutHour, 0, 0);
    if (!now.isBefore(target)) return Duration.zero;
    return target.difference(now);
  }

  Future<void> checkNow() async {
    if (_processing) return;
    _processing = true;

    try {
      final loggedIn = await SessionService.instance.isLoggedIn();
      if (!loggedIn) {
        stop();
        return;
      }

      if (!isAutoLogoutTimeNow()) {
        start();
        return;
      }

      final token = await SessionService.instance.token();

      // Clear the local session and redirect first. Server logout is then
      // completed with the captured token, so a slow network cannot leave the
      // user visually logged in after 10:00 PM.
      await SessionService.instance.expireSession();

      try {
        await AuthService.instance.logout(
          autoLogout: true,
          authTokenOverride: token,
          sessionAlreadyCleared: true,
        );
      } catch (_) {
        // Local logout and redirect are already complete.
      }
    } finally {
      _processing = false;
    }
  }
}
