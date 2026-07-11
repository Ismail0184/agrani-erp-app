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
  static const _attendanceLoginTime = 'attendance_login_time';
  static const _attendanceStatus = 'attendance_status';
  static const _attendanceSyncStatus = 'attendance_sync_status';
  static const _attendanceDate = 'attendance_date';
  static const _loginAfterAutoLogout = 'login_after_auto_logout';
  static const _deviceId = 'device_id';

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
  }

  Future<void> saveAttendanceCache({required String date, required String loginTime, required String status, required String syncStatus}) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_attendanceDate, date);
    await sp.setString(_attendanceLoginTime, loginTime);
    await sp.setString(_attendanceStatus, status);
    await sp.setString(_attendanceSyncStatus, syncStatus);
  }

  Future<Map<String, String>?> todayAttendanceCache() async {
    final sp = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final date = sp.getString(_attendanceDate) ?? '';
    if (date != today) return null;
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

  Future<void> setLoginAfterAutoLogout(bool value) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_loginAfterAutoLogout, value);
  }

  Future<bool> isLoginAfterAutoLogout() async => (await SharedPreferences.getInstance()).getBool(_loginAfterAutoLogout) ?? false;

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

  Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.clear();
  }
}
