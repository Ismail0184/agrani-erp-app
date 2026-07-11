import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../core/api_client.dart';
import '../core/local_db.dart';
import 'collection_service.dart';
import 'order_service.dart';
import 'session_service.dart';

class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  bool _syncing = false;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  Future<bool> isOnline() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return result.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  void startAutoSync() {
    _subscription ??= Connectivity().onConnectivityChanged.listen((result) {
      if (result.any((r) => r != ConnectivityResult.none)) {
        syncIfOnline();
      }
    });
    syncIfOnline();
  }

  Future<void> stopAutoSync() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<Map<String, int>> syncIfOnline() async {
    if (_syncing) return {'attendance': 0, 'gps': 0, 'orders': 0, 'collections': 0, 'audit': 0};
    final online = await isOnline();
    if (!online) return {'attendance': 0, 'gps': 0, 'orders': 0, 'collections': 0, 'audit': 0};
    return syncAll();
  }

  Future<Map<String, int>> syncAll() async {
    if (_syncing) return {'attendance': 0, 'gps': 0, 'orders': 0, 'collections': 0, 'audit': 0};
    _syncing = true;
    final db = await LocalDb.instance.database;
    int orders = 0;
    int collections = 0;
    int gps = 0;
    int attendance = 0;
    int audit = 0;

    try {
      final attRows = await db.query('attendance', where: "IFNULL(sync_status,'Pending') <> 'Synced'");
      for (final a in attRows) {
        try {
          await ApiClient.instance.post('attendance_start', {
            'local_id': a['local_id'],
            'attendance_date': a['attendance_date'],
            'login_time': a['login_time'],
            'latitude': a['login_latitude'],
            'longitude': a['login_longitude'],
            'login_type': 'Offline',
            'internet_status': 'Offline',
          });

          final logoutTime = '${a['logout_time'] ?? ''}';
          if (logoutTime.isNotEmpty && logoutTime != 'null') {
            await ApiClient.instance.post('attendance_logout', {
              'attendance_date': a['attendance_date'],
              'logout_time': a['logout_time'],
              'latitude': a['logout_latitude'],
              'longitude': a['logout_longitude'],
              'auto_logout': int.tryParse('${a['auto_logout'] ?? 0}') == 1 ? 1 : 0,
            });
          }

          await db.delete('attendance', where: 'local_id = ?', whereArgs: [a['local_id']]);
          await SessionService.instance.updateAttendanceSyncStatus('Synced');
          attendance++;
        } catch (_) {}
      }

      final gpsRows = await db.query('gps_tracking', where: "IFNULL(sync_status,'Pending') <> 'Synced'", limit: 300);
      if (gpsRows.isNotEmpty) {
        try {
          await ApiClient.instance.post('gps_batch', {'points': gpsRows});
          final batch = db.batch();
          for (final p in gpsRows) {
            batch.delete('gps_tracking', where: 'local_id = ?', whereArgs: [p['local_id']]);
          }
          await batch.commit(noResult: true);
          gps = gpsRows.length;
        } catch (_) {}
      }

      final orderRows = await db.query('app_order_master', where: "IFNULL(sync_status,'Pending') <> 'Synced'");
      for (final o in orderRows) {
        try {
          await OrderService.instance.syncOneOrder(o);
          orders++;
        } catch (_) {}
      }

      final colRows = await db.query('app_collection_master', where: "IFNULL(sync_status,'Pending') <> 'Synced'");
      for (final c in colRows) {
        try {
          await CollectionService.instance.syncOneCollection(c);
          collections++;
        } catch (_) {}
      }

      final auditRows = await db.query(
        'audit_checklist_pending_actions',
        where: "IFNULL(sync_status,'Pending') <> 'Synced'",
        orderBy: 'created_at ASC',
        limit: 100,
      );
      for (final row in auditRows) {
        try {
          final action = '${row['action'] ?? ''}'.trim();
          final payload = jsonDecode('${row['payload'] ?? '{}'}') as Map<String, dynamic>;
          if (action.isEmpty) continue;

          if (action == 'audit_checklist_save_detail') {
            final attachmentPath = '${payload['attachment_path'] ?? ''}'.trim();
            final uploadPayload = Map<String, dynamic>.from(payload)..remove('attachment_path');
            final data = await ApiClient.instance.post(action, uploadPayload);
            final detailId = int.tryParse('${data['detail_id'] ?? payload['detail_id'] ?? 0}') ?? 0;
            final masterId = int.tryParse('${payload['master_id'] ?? 0}') ?? 0;
            if (attachmentPath.isNotEmpty && detailId > 0 && masterId > 0) {
              await ApiClient.instance.postMultipart(
                'audit_checklist_upload_attachment',
                fields: {'master_id': '$masterId', 'detail_id': '$detailId'},
                fileField: 'attachment',
                filePath: attachmentPath,
              );
            }
          } else {
            await ApiClient.instance.post(action, payload);
          }

          await db.delete('audit_checklist_pending_actions', where: 'local_id = ?', whereArgs: [row['local_id']]);
          audit++;
        } catch (_) {}
      }

      return {'attendance': attendance, 'gps': gps, 'orders': orders, 'collections': collections, 'audit': audit};
    } finally {
      _syncing = false;
    }
  }
}
