import 'dart:async';
import '../core/bangladesh_time.dart';

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../core/local_db.dart';
import 'sync_service.dart';
import 'auto_logout_service.dart';

class GpsService {
  GpsService._();
  static final GpsService instance = GpsService._();

  final _uuid = const Uuid();
  final Battery _battery = Battery();

  static const double minimumMovementMeters = 50;
  static const double acceptableAccuracyMeters = 100;
  static const Duration movingCheckInterval = Duration(minutes: 1);
  static const Duration stationaryAfter = Duration(minutes: 10);
  static const Duration stationaryCheckInterval = Duration(minutes: 5);

  // Agrani ERP GPS will be used in Bangladesh. This prevents the Android
  // emulator/default mock point such as Google Mountain View from being saved.
  static const double _bdMinLat = 20.50;
  static const double _bdMaxLat = 26.90;
  static const double _bdMinLng = 88.00;
  static const double _bdMaxLng = 92.80;

  Timer? _fallbackTimer;
  StreamSubscription<Position>? _positionSubscription;
  bool _running = false;
  bool _capturing = false;
  Position? _lastSavedPosition;
  DateTime? _lastSavedAt;
  DateTime? _stationaryStartedAt;
  Duration _nextInterval = movingCheckInterval;

  bool get isRunning => _running;

  Future<void> startTracking() async {
    if (_running) return;
    if (!AutoLogoutService.instance.canRecordAttendanceAndGpsNow()) return;
    _running = true;

    await _loadLastSavedPoint();

    // Login policy: save GPS point immediately after login.
    await captureCurrentPoint(forceSave: true, reason: 'LOGIN');

    // Main tracking: native position stream with Android foreground service.
    // This is needed because a normal Dart timer is not reliable when the app
    // is minimized or the phone screen is locked.
    await _startPositionStream();

    // Fallback tracking: keeps the 1-minute / 5-minute checking rule even if
    // the native stream does not emit due to device/vendor restrictions.
    _scheduleFallbackCheck(movingCheckInterval);
  }

  Future<void> stopTracking({bool saveLastPoint = true}) async {
    _fallbackTimer?.cancel();
    _fallbackTimer = null;

    await _positionSubscription?.cancel();
    _positionSubscription = null;

    _running = false;

    // Logout policy: save final GPS point immediately on logout.
    if (saveLastPoint) {
      await captureCurrentPoint(forceSave: true, reason: 'LOGOUT');
    }
  }

  Future<void> captureCurrentPoint({bool forceSave = false, String reason = 'MANUAL'}) async {
    if (!AutoLogoutService.instance.canRecordAttendanceAndGpsNow()) return;
    if (_capturing) return;
    _capturing = true;

    try {
      final permissionOk = await _ensureLocationPermission();
      if (!permissionOk) return;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );

      await _handlePosition(position, forceSave: forceSave, reason: reason);
    } catch (_) {
      _nextInterval = movingCheckInterval;
    } finally {
      _capturing = false;
    }
  }

  Future<void> _startPositionStream() async {
    try {
      final permissionOk = await _ensureLocationPermission();
      if (!permissionOk) return;

      await _positionSubscription?.cancel();
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: _streamLocationSettings(),
      ).listen(
        (position) {
          unawaited(_handlePosition(position, reason: 'AUTO_STREAM'));
        },
        onError: (_) {
          _nextInterval = movingCheckInterval;
        },
        cancelOnError: false,
      );
    } catch (_) {
      _nextInterval = movingCheckInterval;
    }
  }

  LocationSettings _streamLocationSettings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: minimumMovementMeters.round(),
        intervalDuration: movingCheckInterval,
        forceLocationManager: false,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Agrani App GPS Tracking',
          notificationText: 'Attendance GPS tracking is running.',
          enableWakeLock: false,
          setOngoing: true,
        ),
      );
    }

    if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: minimumMovementMeters.round(),
        pauseLocationUpdatesAutomatically: true,
        showBackgroundLocationIndicator: true,
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: 50,
    );
  }

  Future<void> _handlePosition(Position position, {bool forceSave = false, String reason = 'AUTO'}) async {
    if (!AutoLogoutService.instance.canRecordAttendanceAndGpsNow()) return;
    if (!_running && !forceSave) return;

    final now = DateTime.now();
    final accuracyOk = position.accuracy > 0 && position.accuracy <= acceptableAccuracyMeters;
    final bangladeshLocationOk = _isBangladeshLocation(position.latitude, position.longitude);

    // Do not save invalid country/default emulator GPS points.
    // Example invalid point: 37.4219983, -122.084 (Google HQ emulator default).
    if (!bangladeshLocationOk) {
      _nextInterval = movingCheckInterval;
      return;
    }

    // Normal policy: save only if GPS accuracy is acceptable.
    // Login/logout forceSave still saves the point but marks low accuracy if needed.
    if (!accuracyOk && !forceSave) {
      _nextInterval = movingCheckInterval;
      return;
    }

    final distanceFromLastSaved = _lastSavedPosition == null
        ? minimumMovementMeters
        : Geolocator.distanceBetween(
            _lastSavedPosition!.latitude,
            _lastSavedPosition!.longitude,
            position.latitude,
            position.longitude,
          );

    final shouldSave = forceSave || _lastSavedPosition == null || distanceFromLastSaved >= minimumMovementMeters;

    if (shouldSave) {
      await _savePoint(position, reason: reason, accuracyOk: accuracyOk);
      _lastSavedPosition = position;
      _lastSavedAt = now;
      _stationaryStartedAt = null;
      _nextInterval = movingCheckInterval;
      return;
    }

    _stationaryStartedAt ??= now;
    final stationaryDuration = now.difference(_stationaryStartedAt!);

    // Stationary policy: after 10 minutes in the same place, check every 5 minutes.
    // This only changes the check interval. It does not save duplicate stationary
    // points because your save rule is minimum 50 meter movement.
    if (stationaryDuration >= stationaryAfter) {
      _nextInterval = stationaryCheckInterval;
    } else {
      _nextInterval = movingCheckInterval;
    }
  }

  void _scheduleFallbackCheck(Duration interval) {
    _fallbackTimer?.cancel();
    if (!_running) return;

    _fallbackTimer = Timer(interval, () async {
      if (!_running) return;
      await captureCurrentPoint(reason: 'AUTO_TIMER');
      _scheduleFallbackCheck(_nextInterval);
    });
  }

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
  }

  Future<void> _savePoint(Position position, {required String reason, required bool accuracyOk}) async {
    if (!AutoLogoutService.instance.canRecordAttendanceAndGpsNow()) return;
    final db = await LocalDb.instance.database;
    final now = BangladeshTime.now();
    final trackingTime = _formatDateTime(now);
    final online = await _isOnline();
    final attendanceId = await _todayAttendanceServerId();
    final batteryPercent = await _batteryPercent();

    await db.insert(
      'gps_tracking',
      {
        'local_id': _uuid.v4(),
        'attendance_id': attendanceId,
        'tracking_date': trackingTime.substring(0, 10),
        'tracking_time': trackingTime,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'speed': position.speed,
        'battery_percent': batteryPercent,
        'internet_status': online ? 'Online' : 'Offline',
        'gps_status': accuracyOk ? 'Enabled' : 'Low Accuracy',
        'sync_status': 'Pending',
        'created_at': BangladeshTime.isoLocal(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    // Online policy: sync instantly whenever internet is available.
    if (online) {
      unawaited(SyncService.instance.syncIfOnline());
    }
  }

  Future<int?> _batteryPercent() async {
    try {
      final level = await _battery.batteryLevel;
      if (level < 0) return null;
      if (level > 100) return 100;
      return level;
    } catch (_) {
      return null;
    }
  }

  Future<int?> _todayAttendanceServerId() async {
    try {
      final db = await LocalDb.instance.database;
      final today = BangladeshTime.date();
      final rows = await db.query(
        'attendance',
        columns: ['server_id'],
        where: 'attendance_date = ?',
        whereArgs: [today],
        orderBy: 'login_time ASC',
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final value = rows.first['server_id'];
      if (value == null) return null;
      return int.tryParse('$value');
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadLastSavedPoint() async {
    if (_lastSavedPosition != null) return;

    try {
      final db = await LocalDb.instance.database;
      final today = BangladeshTime.date();
      final rows = await db.query(
        'gps_tracking',
        where: 'tracking_date = ?',
        whereArgs: [today],
        orderBy: 'created_at DESC',
        limit: 1,
      );
      if (rows.isEmpty) return;

      final lat = (rows.first['latitude'] as num?)?.toDouble();
      final lng = (rows.first['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null || !_isBangladeshLocation(lat, lng)) return;

      _lastSavedPosition = Position(
        latitude: lat,
        longitude: lng,
        timestamp: DateTime.tryParse('${rows.first['created_at']}') ?? DateTime.now(),
        accuracy: (rows.first['accuracy'] as num?)?.toDouble() ?? 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: (rows.first['speed'] as num?)?.toDouble() ?? 0,
        speedAccuracy: 0,
      );
      _lastSavedAt = DateTime.tryParse('${rows.first['created_at']}');
    } catch (_) {}
  }

  Future<bool> _isOnline() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return result.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  static bool _isBangladeshLocation(double latitude, double longitude) {
    return latitude.isFinite &&
        longitude.isFinite &&
        latitude >= _bdMinLat &&
        latitude <= _bdMaxLat &&
        longitude >= _bdMinLng &&
        longitude <= _bdMaxLng;
  }

  String _formatDateTime(DateTime value) {
    return value.toIso8601String().replaceFirst('T', ' ').substring(0, 19);
  }
}
