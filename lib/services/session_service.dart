import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../config/app_config.dart';

class SessionService {
  SessionService._();
  static final SessionService instance = SessionService._();

  static const _token = 'token';
  static const _userId = 'user_id';
  static const _companyId = 'company_id';
  static const _sectionId = 'section_id';
  static const _fullName = 'full_name';
  static const _username = 'username';
  static const _photoUrl = 'photo_url';
  static const _companyName = 'company_name';
  static const _department = 'department';
  static const _designation = 'designation';
  static const _menuPermissions = 'menu_permissions';
  static const _attendanceLoginTime = 'attendance_login_time';
  static const _attendanceStatus = 'attendance_status';
  static const _attendanceSyncStatus = 'attendance_sync_status';
  static const _attendanceDate = 'attendance_date';
  static const _attendanceUserId = 'attendance_user_id';
  static const _deviceId = 'device_id';

  FutureOr<void> Function()? _sessionExpiredHandler;
  bool _expiringSession = false;

  void registerSessionExpiredHandler(FutureOr<void> Function() handler) {
    _sessionExpiredHandler = handler;
  }

  String normalizePhotoUrl(String value) {
    var photo = value.trim().replaceAll('\\', '/');
    if (photo.isEmpty) return AppConfig.defaultUserPhotoUrl;

    photo = photo.replaceAll('/assets/images/../assets/images/', '/assets/images/');

    final lower = photo.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return photo;
    }

    while (photo.startsWith('../')) {
      photo = photo.substring(3);
    }
    while (photo.startsWith('./')) {
      photo = photo.substring(2);
    }
    while (photo.startsWith('/')) {
      photo = photo.substring(1);
    }

    if (photo.startsWith('assets/')) {
      return 'https://agrani-erp.com/$photo';
    }
    if (photo.startsWith('images/')) {
      return 'https://agrani-erp.com/assets/$photo';
    }
    if (photo.startsWith('staff/')) {
      return 'https://agrani-erp.com/assets/images/$photo';
    }

    return 'https://agrani-erp.com/assets/images/staff/staff/$photo';
  }

  Future<void> saveSession({
    required String token,
    required int userId,
    required int companyId,
    required int sectionId,
    required String fullName,
    String username = '',
    String photoUrl = '',
    String companyName = '',
    String department = '',
    String designation = '',
    List<Map<String, dynamic>> menuPermissions = const [],
  }) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_token, token);
    await sp.setInt(_userId, userId);
    await sp.setInt(_companyId, companyId);
    await sp.setInt(_sectionId, sectionId);
    await sp.setString(_fullName, fullName);
    await sp.setString(_username, username);
    await sp.setString(_photoUrl, normalizePhotoUrl(photoUrl));
    await sp.setString(_companyName, companyName);
    await sp.setString(_department, department);
    await sp.setString(_designation, designation);
    await sp.setString(_menuPermissions, jsonEncode(menuPermissions));
  }

  Future<void> saveAttendanceCache({required String date, required String loginTime, required String status, required String syncStatus}) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_attendanceDate, date);
    await sp.setInt(_attendanceUserId, sp.getInt(_userId) ?? 0);
    await sp.setString(_attendanceLoginTime, loginTime);
    await sp.setString(_attendanceStatus, status);
    await sp.setString(_attendanceSyncStatus, syncStatus);
  }

  Future<Map<String, String>?> todayAttendanceCache() async {
    final sp = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final date = sp.getString(_attendanceDate) ?? '';
    final currentUserId = sp.getInt(_userId) ?? 0;
    final attendanceUserId = sp.getInt(_attendanceUserId) ?? 0;
    if (date != today || currentUserId <= 0 || attendanceUserId != currentUserId) return null;
    return {
      'attendance_date': date,
      'login_time': sp.getString(_attendanceLoginTime) ?? '',
      'attendance_status': sp.getString(_attendanceStatus) ?? '-',
      'sync_status': sp.getString(_attendanceSyncStatus) ?? '-',
    };
  }

  Future<void> updateAttendanceSyncStatus(String syncStatus) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_attendanceSyncStatus, syncStatus);
  }

  Future<String> deviceId() async {
    final sp = await SharedPreferences.getInstance();
    var value = sp.getString(_deviceId) ?? '';
    if (value.trim().isEmpty) {
      value = const Uuid().v4();
      await sp.setString(_deviceId, value);
    }
    return value;
  }

  Future<bool> isLoggedIn() async => (await token())?.isNotEmpty == true;
  Future<String?> token() async => (await SharedPreferences.getInstance()).getString(_token);
  Future<int> userId() async => (await SharedPreferences.getInstance()).getInt(_userId) ?? 0;
  Future<int> companyId() async => (await SharedPreferences.getInstance()).getInt(_companyId) ?? 0;
  Future<int> sectionId() async => (await SharedPreferences.getInstance()).getInt(_sectionId) ?? 0;
  Future<String> fullName() async => (await SharedPreferences.getInstance()).getString(_fullName) ?? '';
  Future<String> username() async => (await SharedPreferences.getInstance()).getString(_username) ?? '';
  Future<String> photoUrl() async => normalizePhotoUrl((await SharedPreferences.getInstance()).getString(_photoUrl) ?? AppConfig.defaultUserPhotoUrl);
  Future<String> companyName() async => (await SharedPreferences.getInstance()).getString(_companyName) ?? '';
  Future<String> department() async => (await SharedPreferences.getInstance()).getString(_department) ?? '';
  Future<String> designation() async => (await SharedPreferences.getInstance()).getString(_designation) ?? '';

  Future<void> saveMenuPermissions(List<Map<String, dynamic>> permissions) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_menuPermissions, jsonEncode(permissions));
  }

  Future<List<Map<String, dynamic>>> menuPermissions() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_menuPermissions) ?? '[]';
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> expireSession() async {
    if (_expiringSession) return;
    _expiringSession = true;

    try {
      await clear();
      final handler = _sessionExpiredHandler;
      if (handler != null) {
        await handler();
      }
    } finally {
      _expiringSession = false;
    }
  }

  Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await Future.wait([
      sp.remove(_token),
      sp.remove(_userId),
      sp.remove(_companyId),
      sp.remove(_sectionId),
      sp.remove(_fullName),
      sp.remove(_username),
      sp.remove(_photoUrl),
      sp.remove(_companyName),
      sp.remove(_department),
      sp.remove(_designation),
      sp.remove(_menuPermissions),
      sp.remove('login_after_auto_logout'),
    ]);
  }
}
