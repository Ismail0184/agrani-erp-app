import 'package:geolocator/geolocator.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../core/api_client.dart';
import '../core/local_db.dart';
import 'gps_service.dart';
import 'master_data_service.dart';
import 'session_service.dart';
import 'sync_service.dart';
import 'auto_logout_service.dart';

class ActiveDeviceLoginException implements Exception {
  final String message;
  const ActiveDeviceLoginException(this.message);
  @override
  String toString() => message;
}

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();
  final _uuid = const Uuid();

  Future<void> login(String username, String password, {bool forceLogoutPrevious = false}) async {
    final deviceId = await SessionService.instance.deviceId();
    late final Map<String, dynamic> data;
    try {
      data = await ApiClient.instance.post('login', {
        'username': username,
        'password': password,
        'device_id': deviceId,
        'device_name': 'Android/iOS',
        if (forceLogoutPrevious) 'force_logout_previous': 1,
      });
    } on ApiException catch (e) {
      if (e.statusCode == 409 || '${e.data['reason'] ?? ''}' == 'ACTIVE_SESSION') {
        throw ActiveDeviceLoginException(e.message);
      }
      rethrow;
    }
    final user = data['user'] as Map<String, dynamic>;
    final company = data['company'] is Map ? Map<String, dynamic>.from(data['company'] as Map) : <String, dynamic>{};
    await SessionService.instance.saveSession(
      token: data['token'].toString(),
      userId: int.tryParse('${user['user_id']}') ?? 0,
      companyId: int.tryParse('${user['company_id']}') ?? 0,
      sectionId: int.tryParse('${user['section_id']}') ?? 0,
      fullName: '${user['full_name'] ?? username}',
      username: '${user['username'] ?? username}',
      photoUrl: '${user['photo_url'] ?? ''}',
      companyName: '${company['company_name'] ?? company['name'] ?? ''}',
      department: '${user['department'] ?? user['department_name'] ?? ''}',
    );
    await SessionService.instance.setLoginAfterAutoLogout(AutoLogoutService.instance.isAutoLogoutTimeNow());
    await MasterDataService.instance.downloadMasterData(silent: true);
    SyncService.instance.startAutoSync();

    // Company rule: after 10:00 PM Bangladesh time, the user can login and use
    // the app, but attendance and GPS tracking must not be recorded.
    if (AutoLogoutService.instance.canRecordAttendanceAndGpsNow()) {
      await createAttendanceOnline();
      await GpsService.instance.startTracking();
      AutoLogoutService.instance.start();
    } else {
      await GpsService.instance.stopTracking(saveLastPoint: false);
      AutoLogoutService.instance.stop();
    }
  }

  Future<void> createAttendanceOnline() async {
    if (!AutoLogoutService.instance.canRecordAttendanceAndGpsNow()) return;

    final db = await LocalDb.instance.database;
    final today = _formatDate(_bangladeshNow());
    final existing = await db.query('attendance', where: 'attendance_date = ?', whereArgs: [today], limit: 1);
    if (existing.isNotEmpty) return;

    final now = _bangladeshNow();
    Position? pos;
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        final current = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 15),
          ),
        );
        if (_isBangladeshLocation(current.latitude, current.longitude)) {
          pos = current;
        }
      }
    } catch (_) {}

    final localId = _uuid.v4();
    final loginTime = _formatBangladeshDateTime(now);

    try {
      final res = await ApiClient.instance.post('attendance_start', {
        'local_id': localId,
        'attendance_date': today,
        'login_time': loginTime,
        'latitude': pos?.latitude,
        'longitude': pos?.longitude,
        'login_type': 'Online',
        'internet_status': 'Online',
      });
      final att = res['attendance'] as Map<String, dynamic>?;
      await _saveLocalAttendance(localId, today, loginTime, pos, 'Synced', serverId: int.tryParse('${att?['id'] ?? 0}'));
    } catch (_) {
      await _saveLocalAttendance(localId, today, loginTime, pos, 'Pending');
    }
  }

  static bool _isBangladeshLocation(double latitude, double longitude) {
    return latitude.isFinite &&
        longitude.isFinite &&
        latitude >= 20.50 &&
        latitude <= 26.90 &&
        longitude >= 88.00 &&
        longitude <= 92.80;
  }

  Future<void> _saveLocalAttendance(String localId, String date, String loginTime, Position? pos, String syncStatus, {int? serverId}) async {
    if (!AutoLogoutService.instance.canRecordAttendanceAndGpsNow()) return;

    final db = await LocalDb.instance.database;
    final now = _bangladeshNow();
    final status = now.hour < 9 || (now.hour == 9 && now.minute <= 15) ? 'Present' : 'Late';
    await db.insert('attendance', {
      'local_id': localId,
      'server_id': serverId,
      'attendance_date': date,
      'login_time': loginTime,
      'login_latitude': pos?.latitude,
      'login_longitude': pos?.longitude,
      'attendance_status': status,
      'sync_status': syncStatus,
      'auto_logout': 0,
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await SessionService.instance.saveAttendanceCache(date: date, loginTime: loginTime, status: status, syncStatus: syncStatus);
    if (syncStatus == 'Synced') {
      await db.delete('attendance', where: 'local_id = ?', whereArgs: [localId]);
    }
    await SyncService.instance.syncIfOnline();
  }

  Future<void> logout({bool autoLogout = false}) async {
    final canRecordNow = AutoLogoutService.instance.canRecordAttendanceAndGpsNow();
    final logoutTime = _formatBangladeshDateTime(_bangladeshNow());
    final logoutDate = logoutTime.substring(0, 10);
    final Position? pos = canRecordNow ? await _currentValidPosition() : null;

    await GpsService.instance.stopTracking(saveLastPoint: canRecordNow && !autoLogout);

    try {
      await ApiClient.instance.post('attendance_logout', {
        'attendance_date': logoutDate,
        'logout_time': logoutTime,
        'latitude': pos?.latitude,
        'longitude': pos?.longitude,
        'auto_logout': autoLogout ? 1 : 0,
      });
    } catch (_) {
      await _saveLogoutLocally(logoutDate: logoutDate, logoutTime: logoutTime, pos: pos, autoLogout: autoLogout);
    }

    try {
      await ApiClient.instance.post('logout', {});
    } catch (_) {}

    await SyncService.instance.stopAutoSync();
    AutoLogoutService.instance.stop();
    await SessionService.instance.clear();
  }

  Future<Position?> _currentValidPosition() async {
    if (!AutoLogoutService.instance.canRecordAttendanceAndGpsNow()) return null;

    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.always && permission != LocationPermission.whileInUse) return null;
      final current = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!_isBangladeshLocation(current.latitude, current.longitude)) return null;
      return current;
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveLogoutLocally({required String logoutDate, required String logoutTime, required Position? pos, required bool autoLogout}) async {
    final db = await LocalDb.instance.database;
    final cache = await SessionService.instance.todayAttendanceCache();
    final rows = await db.query('attendance', where: 'attendance_date = ?', whereArgs: [logoutDate], limit: 1);
    final loginTime = cache?['login_time']?.isNotEmpty == true ? cache!['login_time']! : '$logoutDate 09:00:00';
    final workingMinutes = _minutesBetween(loginTime, logoutTime);

    if (rows.isNotEmpty) {
      await db.update('attendance', {
        'logout_time': logoutTime,
        'logout_latitude': pos?.latitude,
        'logout_longitude': pos?.longitude,
        'total_working_minutes': workingMinutes,
        'auto_logout': autoLogout ? 1 : 0,
        'sync_status': 'Pending',
        'updated_at': DateTime.now().toIso8601String(),
      }, where: 'local_id = ?', whereArgs: [rows.first['local_id']]);
      return;
    }

    // If user logged in again after 10 PM, there may be no attendance row. In
    // that case do not create a new attendance entry.
    if (cache == null || cache['login_time']?.isNotEmpty != true || !AutoLogoutService.instance.canRecordAttendanceAndGpsNow()) {
      return;
    }

    await db.insert('attendance', {
      'local_id': _uuid.v4(),
      'attendance_date': logoutDate,
      'login_time': loginTime,
      'logout_time': logoutTime,
      'logout_latitude': pos?.latitude,
      'logout_longitude': pos?.longitude,
      'total_working_minutes': workingMinutes,
      'attendance_status': cache['attendance_status'] ?? 'Present',
      'auto_logout': autoLogout ? 1 : 0,
      'sync_status': 'Pending',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  int _minutesBetween(String start, String end) {
    try {
      final s = DateTime.parse(start.replaceFirst(' ', 'T'));
      final e = DateTime.parse(end.replaceFirst(' ', 'T'));
      return e.difference(s).inMinutes < 0 ? 0 : e.difference(s).inMinutes;
    } catch (_) {
      return 0;
    }
  }

  DateTime _bangladeshNow() {
    final bd = DateTime.now().toUtc().add(const Duration(hours: 6));
    return DateTime(bd.year, bd.month, bd.day, bd.hour, bd.minute, bd.second);
  }

  String _formatDate(DateTime value) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)}';
  }

  String _formatBangladeshDateTime(DateTime value) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} ${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }
}
