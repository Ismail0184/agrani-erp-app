import '../core/api_client.dart';
import 'session_service.dart';

class MenuPermissionService {
  MenuPermissionService._();
  static final MenuPermissionService instance = MenuPermissionService._();

  Future<List<Map<String, dynamic>>> load({bool refresh = false}) async {
    final cached = await SessionService.instance.menuPermissions();
    if (!refresh) return _sorted(cached);

    try {
      final data = await ApiClient.instance.get('main_menu_permissions');
      final permissions = data['permissions'] is List
          ? (data['permissions'] as List)
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
          : <Map<String, dynamic>>[];
      await SessionService.instance.saveMenuPermissions(permissions);
      return _sorted(permissions);
    } catch (_) {
      return _sorted(cached);
    }
  }

  String normalizeUrl(String value) {
    var url = value.trim().replaceAll('\\', '/').toLowerCase();
    if (url.contains('?')) url = url.split('?').first;
    if (url.contains('#')) url = url.split('#').first;
    if (url.contains('/')) url = url.split('/').last;
    return url;
  }

  Map<String, dynamic>? findByUrl(
    List<Map<String, dynamic>> permissions,
    String url,
  ) {
    final target = normalizeUrl(url);
    for (final permission in permissions) {
      if (normalizeUrl('${permission['url'] ?? ''}') == target) {
        return permission;
      }
    }
    return null;
  }

  bool hasUrl(List<Map<String, dynamic>> permissions, String url) {
    return findByUrl(permissions, url) != null;
  }

  List<Map<String, dynamic>> _sorted(List<Map<String, dynamic>> values) {
    final result = values.map((item) => Map<String, dynamic>.from(item)).toList();
    result.sort((a, b) {
      final aSl = int.tryParse('${a['sl'] ?? 0}') ?? 0;
      final bSl = int.tryParse('${b['sl'] ?? 0}') ?? 0;
      if (aSl != bSl) return aSl.compareTo(bSl);
      final aId = int.tryParse('${a['main_menu_id'] ?? 0}') ?? 0;
      final bId = int.tryParse('${b['main_menu_id'] ?? 0}') ?? 0;
      return aId.compareTo(bId);
    });
    return result;
  }
}
