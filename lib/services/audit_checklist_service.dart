import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';

import '../core/api_client.dart';
import '../core/local_db.dart';
import '../models/audit_checklist_models.dart';
import '../models/company_model.dart';

class AuditChecklistService {
  AuditChecklistService._();
  static final AuditChecklistService instance = AuditChecklistService._();

  Future<List<CompanyModel>> branches() async {
    final data = await ApiClient.instance.get('audit_branch_list');
    final rows = data['rows'] as List? ?? [];
    final items = rows
        .map((e) => CompanyModel.fromMap(Map<String, dynamic>.from(e as Map)))
        .where((e) => e.companyName.trim().isNotEmpty)
        .toList();
    items.sort((a, b) => a.companyId.compareTo(b.companyId));
    return items;
  }

  Future<List<AuditChecklistMasterModel>> index({String date = '', int companyId = 0}) async {
    final data = await ApiClient.instance.get('audit_checklist_index', query: {
      if (date.trim().isNotEmpty) 'date': date,
      if (companyId > 0) 'company_id': '$companyId',
    });
    final rows = data['rows'] as List? ?? [];
    return rows.map((e) => AuditChecklistMasterModel.fromMap(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<AuditChecklistMasterModel> initiate(CompanyModel branch) async {
    final pos = await _currentPosition();
    final data = await ApiClient.instance.post('audit_checklist_initiate', {
      'company_id': branch.companyId,
      'latitude': pos?.latitude,
      'longitude': pos?.longitude,
      'location_accuracy': pos?.accuracy,
    });
    return AuditChecklistMasterModel.fromMap(Map<String, dynamic>.from(data['master'] as Map));
  }

  Future<List<AuditChecklistGroupModel>> groups(int masterId) async {
    final data = await ApiClient.instance.get('audit_checklist_group_list', query: {'master_id': '$masterId'});
    final rows = data['rows'] as List? ?? [];
    final items = rows
        .map((e) => AuditChecklistGroupModel.fromMap(Map<String, dynamic>.from(e as Map)))
        .where((e) => e.displayName.trim().isNotEmpty)
        .toList();
    items.sort((a, b) => a.groupId.compareTo(b.groupId));
    return items;
  }

  Future<List<AuditChecklistSubGroupModel>> subGroups({required int masterId, required int groupId}) async {
    final data = await ApiClient.instance.get('audit_checklist_sub_group_list', query: {
      'master_id': '$masterId',
      'group_id': '$groupId',
    });
    final rows = data['rows'] as List? ?? [];
    final items = rows
        .map((e) => AuditChecklistSubGroupModel.fromMap(Map<String, dynamic>.from(e as Map)))
        .where((e) => e.displayName.trim().isNotEmpty)
        .toList();
    items.sort((a, b) => a.subGroupId.compareTo(b.subGroupId));
    return items;
  }

  Future<List<AuditChecklistDetailModel>> details(int masterId) async {
    final List<AuditChecklistDetailModel> merged = [];

    try {
      final data = await ApiClient.instance.get('audit_checklist_details', query: {'master_id': '$masterId'});
      final rows = data['rows'] as List? ?? [];
      merged.addAll(rows.map((e) => AuditChecklistDetailModel.fromMap(Map<String, dynamic>.from(e as Map))));
    } catch (e) {
      if (!_isOfflineError(e)) rethrow;
    }

    merged.addAll(await _pendingDetails(masterId));
    return merged;
  }

  /// Returns true when saved into local pending queue because internet/API was not reachable.
  Future<bool> saveDetail({
    required int masterId,
    int detailId = 0,
    required AuditChecklistGroupModel group,
    required AuditChecklistSubGroupModel subGroup,
    required String statusValue,
    required String remarks,
    required String value,
    String othersText = '',
    String attachmentPath = '',
  }) async {
    final payload = {
      'master_id': masterId,
      'detail_id': detailId,
      'group_id': group.groupId,
      'group_name': group.displayName,
      'sub_group_id': subGroup.subGroupId,
      'sub_group_name': subGroup.displayName,
      'status_value': statusValue,
      'remarks': remarks,
      'value': value,
      'others_text': othersText,
      if (attachmentPath.trim().isNotEmpty) 'attachment_path': attachmentPath,
    };

    try {
      final data = await ApiClient.instance.post('audit_checklist_save_detail', payload);
      final detailIdSaved = int.tryParse('${data['detail_id'] ?? detailId}') ?? detailId;
      if (attachmentPath.trim().isNotEmpty && detailIdSaved > 0) {
        await uploadAttachment(masterId: masterId, detailId: detailIdSaved, filePath: attachmentPath);
      }
      return false;
    } catch (e) {
      if (!_isOfflineError(e)) rethrow;
      await _queuePendingAction('audit_checklist_save_detail', payload);
      return true;
    }
  }

  Future<void> uploadAttachment({required int masterId, required int detailId, required String filePath}) async {
    await ApiClient.instance.postMultipart(
      'audit_checklist_upload_attachment',
      fields: {'master_id': '$masterId', 'detail_id': '$detailId'},
      fileField: 'attachment',
      filePath: filePath,
    );
  }

  Future<void> clearDenomination(int masterId) async {
    try {
      await ApiClient.instance.post('audit_checklist_denomination_clear', {'master_id': masterId});
    } catch (e) {
      if (!_isOfflineError(e)) rethrow;
      await _queuePendingAction('audit_checklist_denomination_clear', {'master_id': masterId});
    }
  }

  Future<bool> saveDenomination({required int masterId, required List<Map<String, dynamic>> items}) async {
    final payload = {'master_id': masterId, 'items': items};
    try {
      await ApiClient.instance.post('audit_checklist_denomination_save', payload);
      return false;
    } catch (e) {
      if (!_isOfflineError(e)) rethrow;
      await _queuePendingAction('audit_checklist_denomination_save', payload);
      return true;
    }
  }

  Future<void> updatePendingLocalDetail({
    required int masterId,
    required int subGroupId,
    required String statusValue,
    required String remarks,
    required String value,
    String othersText = '',
  }) async {
    final db = await LocalDb.instance.database;
    final rows = await db.query(
      'audit_checklist_pending_actions',
      where: "action = ? AND IFNULL(sync_status,'Pending') <> 'Synced'",
      whereArgs: ['audit_checklist_save_detail'],
    );

    for (final row in rows) {
      try {
        final payload = jsonDecode('${row['payload']}') as Map<String, dynamic>;
        final payloadMasterId = int.tryParse('${payload['master_id'] ?? 0}') ?? 0;
        final payloadSubGroupId = int.tryParse('${payload['sub_group_id'] ?? 0}') ?? 0;
        if (payloadMasterId == masterId && payloadSubGroupId == subGroupId) {
          payload['status_value'] = statusValue;
          payload['remarks'] = remarks;
          payload['value'] = value;
          payload['others_text'] = othersText;
          await db.update(
            'audit_checklist_pending_actions',
            {'payload': jsonEncode(payload), 'created_at': DateTime.now().toIso8601String()},
            where: 'local_id = ?',
            whereArgs: [row['local_id']],
          );
          return;
        }
      } catch (_) {}
    }
  }

  Future<void> deletePendingLocalDetail({required int masterId, required int subGroupId}) async {
    final db = await LocalDb.instance.database;
    final rows = await db.query(
      'audit_checklist_pending_actions',
      where: "action = ? AND IFNULL(sync_status,'Pending') <> 'Synced'",
      whereArgs: ['audit_checklist_save_detail'],
    );

    for (final row in rows) {
      try {
        final payload = jsonDecode('${row['payload']}') as Map<String, dynamic>;
        final payloadMasterId = int.tryParse('${payload['master_id'] ?? 0}') ?? 0;
        final payloadSubGroupId = int.tryParse('${payload['sub_group_id'] ?? 0}') ?? 0;
        if (payloadMasterId == masterId && payloadSubGroupId == subGroupId) {
          await db.delete('audit_checklist_pending_actions', where: 'local_id = ?', whereArgs: [row['local_id']]);
        }
      } catch (_) {}
    }
  }

  Future<void> deleteDetail(int detailId) async {
    try {
      await ApiClient.instance.post('audit_checklist_delete_detail', {'detail_id': detailId});
    } catch (e) {
      if (!_isOfflineError(e)) rethrow;
      await _queuePendingAction('audit_checklist_delete_detail', {'detail_id': detailId});
    }
  }

  Future<void> cancel(int masterId) async {
    await ApiClient.instance.post('audit_checklist_cancel', {'master_id': masterId});
  }

  Future<void> confirm(int masterId) async {
    await ApiClient.instance.post('audit_checklist_confirm', {'master_id': masterId});
  }

  Future<void> _queuePendingAction(String action, Map<String, dynamic> payload) async {
    final db = await LocalDb.instance.database;
    final id = 'AUD-${DateTime.now().microsecondsSinceEpoch}';
    await db.insert('audit_checklist_pending_actions', {
      'local_id': id,
      'action': action,
      'payload': jsonEncode(payload),
      'sync_status': 'Pending',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<AuditChecklistDetailModel>> _pendingDetails(int masterId) async {
    final db = await LocalDb.instance.database;
    final rows = await db.query(
      'audit_checklist_pending_actions',
      where: "IFNULL(sync_status,'Pending') <> 'Synced'",
      orderBy: 'created_at ASC',
    );

    final List<AuditChecklistDetailModel> items = [];
    for (final row in rows) {
      try {
        final action = '${row['action'] ?? ''}';
        final payload = jsonDecode('${row['payload']}') as Map<String, dynamic>;
        final payloadMasterId = int.tryParse('${payload['master_id'] ?? 0}') ?? 0;
        if (payloadMasterId != masterId) continue;
        if (action == 'audit_checklist_denomination_save') {
          final denItems = payload['items'] is List ? payload['items'] as List : [];
          final total = denItems.fold<double>(0, (p, e) {
            if (e is! Map) return p;
            return p + (double.tryParse('${e['amount'] ?? 0}') ?? 0);
          });
          items.add(AuditChecklistDetailModel(
            id: -(int.tryParse('${row['local_id']}'.replaceAll(RegExp(r'[^0-9]'), '')) ?? DateTime.now().microsecondsSinceEpoch),
            masterId: masterId,
            groupId: 2,
            groupName: 'Denomination',
            subGroupId: 6,
            subGroupName: 'Denomination Sheet',
            statusValue: 'Yes',
            remarks: 'Saved locally. Pending sync.',
            value: total.toStringAsFixed(2),
            entryAt: '${row['created_at'] ?? ''}',
          ));
          continue;
        }
        if (action != 'audit_checklist_save_detail') continue;
        items.add(AuditChecklistDetailModel(
          id: -(int.tryParse('${row['local_id']}'.replaceAll(RegExp(r'[^0-9]'), '')) ?? DateTime.now().microsecondsSinceEpoch),
          masterId: masterId,
          groupId: int.tryParse('${payload['group_id'] ?? 0}') ?? 0,
          groupName: '${payload['group_name'] ?? ''}',
          subGroupId: int.tryParse('${payload['sub_group_id'] ?? 0}') ?? 0,
          subGroupName: '${payload['sub_group_name'] ?? ''}',
          statusValue: '${payload['status_value'] ?? ''}',
          remarks: '${payload['remarks'] ?? ''}',
          value: '${payload['value'] ?? ''}',
          othersText: '${payload['others_text'] ?? ''}',
          attachmentUrl: '${payload['attachment_path'] ?? ''}',
          entryAt: '${row['created_at'] ?? ''}',
        ));
      } catch (_) {}
    }
    return items;
  }

  bool _isOfflineError(Object e) {
    if (e is TimeoutException) return true;
    final msg = e.toString().toLowerCase();
    return msg.contains('socketexception') ||
        msg.contains('failed host lookup') ||
        msg.contains('network is unreachable') ||
        msg.contains('connection refused') ||
        msg.contains('connection closed') ||
        msg.contains('connection reset') ||
        msg.contains('timed out') ||
        msg.contains('timeout') ||
        msg.contains('xmlhttprequest error') ||
        msg.contains('no address associated with hostname');
  }

  Future<Position?> _currentPosition() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return null;

      // Do not block checklist initiation for a long time. First use the last
      // known valid Bangladesh location if available, then try a short fresh
      // GPS request. This still saves latitude, longitude and accuracy when
      // the phone can provide a location, but avoids long loading on slow GPS.
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && _isBangladeshLocation(last.latitude, last.longitude)) {
        return last;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 7),
        ),
      );
      if (!_isBangladeshLocation(pos.latitude, pos.longitude)) return null;
      return pos;
    } catch (_) {
      return null;
    }
  }

  bool _isBangladeshLocation(double latitude, double longitude) {
    return latitude.isFinite && longitude.isFinite && latitude >= 20.50 && latitude <= 26.90 && longitude >= 88.00 && longitude <= 92.80;
  }
}
