import 'package:uuid/uuid.dart';
import '../core/api_client.dart';
import '../core/local_db.dart';
import '../models/outlet_model.dart';
import '../models/collection_ledger_model.dart';
import '../models/route_model.dart';

class CollectionService {
  CollectionService._();
  static final CollectionService instance = CollectionService._();
  final _uuid = const Uuid();

  static const List<String> channels = ['Cash', 'Bank', 'MFS', 'POS'];

  String _newCollectionNo() => 'COL-${DateTime.now().millisecondsSinceEpoch}';
  bool _isServerId(String id) => id.startsWith('server:');
  bool _isServerLineId(String id) => id.startsWith('server_detail:');
  String _serverNo(String id) => id.replaceFirst('server:', '');
  int _serverDetailId(String id) => int.tryParse(id.replaceFirst('server_detail:', '')) ?? 0;

  Future<List<CollectionLedgerModel>> ledgerList(String channel) async {
    final data = await ApiClient.instance.get('collection_ledger_list', query: {'channel': channel});
    final rows = data['rows'] as List? ?? [];
    return rows.map((e) => CollectionLedgerModel.fromMap(Map<String, dynamic>.from(e as Map))).where((e) => e.displayName.trim().isNotEmpty).toList();
  }


  Future<double> outletCurrentBalance(int outletId) async {
    final data = await ApiClient.instance.get(
      'outlet_current_balance',
      query: {'outlet_id': '$outletId'},
    );
    return double.tryParse('${data['opening_balance'] ?? 0}') ?? 0;
  }

  Future<List<Map<String, dynamic>>> listCollections({
    String? from,
    String? to,
    int? outletId,
    String? status,
    bool onlineOnly = false,
    bool includeLocalPending = true,
  }) async {
    final db = await LocalDb.instance.database;
    final result = <Map<String, dynamic>>[];

    try {
      final data = await ApiClient.instance.get('collection_list', query: {
        if (from != null && from.isNotEmpty) 'from': from,
        if (to != null && to.isNotEmpty) 'to': to,
        if (outletId != null && outletId > 0) 'outlet_id': '$outletId',
        if (status != null && status.isNotEmpty) 'status': status,
        'limit': '300',
      });
      for (final raw in (data['rows'] as List? ?? [])) {
        final row = Map<String, dynamic>.from(raw as Map);
        row['server_id'] = row['id'];
        row['local_id'] = 'server:${row['collection_no']}';
        row['source'] = 'online';
        result.add(row);
      }
    } catch (_) {
      if (onlineOnly) return result;
    }

    if (!onlineOnly && includeLocalPending) {
      final where = <String>[];
      final args = <Object?>[];
      if (from != null && from.isNotEmpty) { where.add('m.collection_date >= ?'); args.add(from); }
      if (to != null && to.isNotEmpty) { where.add('m.collection_date <= ?'); args.add(to); }
      if (status != null && status.isNotEmpty) { where.add('m.status = ?'); args.add(status); }
      if (outletId != null && outletId > 0) { where.add('d.outlet_id = ?'); args.add(outletId); }
      where.add("IFNULL(m.sync_status,'Pending') <> 'Synced'");
      final sql = '''
        SELECT DISTINCT m.* FROM app_collection_master m
        LEFT JOIN app_collection_details d ON d.collection_local_id = m.local_id
        WHERE ${where.join(' AND ')}
        ORDER BY m.created_at DESC
      ''';
      final localRows = await db.rawQuery(sql, args);
      for (final r in localRows) {
        final row = Map<String, dynamic>.from(r);
        row['source'] = 'local';
        result.insert(0, row);
      }
    }
    return result;
  }

  Future<String> createHeader({required String collectionDate}) async {
    final db = await LocalDb.instance.database;
    final localId = _uuid.v4();
    await db.insert('app_collection_master', {
      'local_id': localId,
      'collection_no': _newCollectionNo(),
      'collection_date': collectionDate,
      'status': 'Draft',
      'sync_status': 'Pending',
      'created_at': DateTime.now().toIso8601String(),
    });
    return localId;
  }

  Future<void> addLine({
    required String collectionLocalId,
    required String collectionNo,
    required OutletRouteModel route,
    required OutletModel outlet,
    required double openingBalance,
    required double closingBalance,
    required double amount,
    required String channel,
    required CollectionLedgerModel ledger,
    String remarks = '',
  }) async {
    final db = await LocalDb.instance.database;
    await db.insert('app_collection_details', {
      'local_id': _uuid.v4(),
      'collection_local_id': collectionLocalId,
      'collection_no': collectionNo,
      'route_id': route.routeId,
      'route_name': route.displayName,
      'outlet_id': outlet.outletId,
      'outlet_name': outlet.outletName,
      'opening_balance': openingBalance,
      'amount': amount,
      'closing_balance': closingBalance,
      'payment_type': channel,
      'collection_channel': channel,
      'ledger_id': ledger.ledgerId,
      'ledger_name': ledger.displayName,
      'remarks': remarks,
      'sync_status': 'Pending',
      'created_at': DateTime.now().toIso8601String(),
    });
    await LocalDb.instance.recalcCollection(collectionLocalId);
  }

  Future<Map<String, dynamic>?> getCollection(String localId) async {
    if (_isServerId(localId)) {
      final no = _serverNo(localId);
      final data = await ApiClient.instance.get('collection_details', query: {'collection_no': no});
      final row = Map<String, dynamic>.from(data['collection'] as Map);
      row['server_id'] = row['id'];
      row['local_id'] = localId;
      row['source'] = 'online';
      return row;
    }
    final db = await LocalDb.instance.database;
    final rows = await db.query('app_collection_master', where: 'local_id = ?', whereArgs: [localId], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> getLines(String collectionLocalId) async {
    if (_isServerId(collectionLocalId)) {
      final no = _serverNo(collectionLocalId);
      final data = await ApiClient.instance.get('collection_details', query: {'collection_no': no});
      final lines = <Map<String, dynamic>>[];
      for (final raw in (data['lines'] as List? ?? [])) {
        final row = Map<String, dynamic>.from(raw as Map);
        row['server_id'] = row['id'];
        row['local_id'] = 'server_detail:${row['id']}';
        row['source'] = 'online';
        lines.add(row);
      }
      return lines;
    }
    final db = await LocalDb.instance.database;
    return db.query('app_collection_details', where: 'collection_local_id = ?', whereArgs: [collectionLocalId], orderBy: 'created_at ASC');
  }

  Future<void> updateLine({required String lineLocalId, required double amount, String? remarks}) async {
    if (_isServerLineId(lineLocalId)) {
      await ApiClient.instance.post('collection_line_update', {
        'detail_id': _serverDetailId(lineLocalId),
        'amount': amount,
        'remarks': remarks,
      });
      return;
    }
    final db = await LocalDb.instance.database;
    final rows = await db.query('app_collection_details', where: 'local_id = ?', whereArgs: [lineLocalId], limit: 1);
    if (rows.isEmpty) return;
    final collectionLocalId = '${rows.first['collection_local_id']}';
    final openingBalance = double.tryParse('${rows.first['opening_balance'] ?? 0}') ?? 0;
    await db.update('app_collection_details', {
      'amount': amount,
      'closing_balance': openingBalance + amount,
      if (remarks != null) 'remarks': remarks,
      'sync_status': 'Pending',
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'local_id = ?', whereArgs: [lineLocalId]);
    await LocalDb.instance.recalcCollection(collectionLocalId);
  }

  Future<void> deleteLine(String lineLocalId) async {
    if (_isServerLineId(lineLocalId)) {
      await ApiClient.instance.post('collection_line_delete', {'detail_id': _serverDetailId(lineLocalId)});
      return;
    }
    final db = await LocalDb.instance.database;
    final rows = await db.query('app_collection_details', where: 'local_id = ?', whereArgs: [lineLocalId], limit: 1);
    if (rows.isEmpty) return;
    final collectionLocalId = '${rows.first['collection_local_id']}';
    await db.delete('app_collection_details', where: 'local_id = ?', whereArgs: [lineLocalId]);
    await LocalDb.instance.recalcCollection(collectionLocalId);
  }

  Future<void> deleteCollection(String collectionLocalId) async {
    if (_isServerId(collectionLocalId)) {
      await ApiClient.instance.post('collection_cancel', {'collection_no': _serverNo(collectionLocalId)});
      return;
    }
    final db = await LocalDb.instance.database;
    await db.delete('app_collection_details', where: 'collection_local_id = ?', whereArgs: [collectionLocalId]);
    await db.delete('app_collection_master', where: 'local_id = ?', whereArgs: [collectionLocalId]);
  }

  Future<void> submitCollection(String collectionLocalId, {bool finalConfirm = false}) async {
    if (_isServerId(collectionLocalId)) {
      await ApiClient.instance.post('collection_confirm', {'collection_no': _serverNo(collectionLocalId), 'confirm_final': finalConfirm});
      return;
    }
    final db = await LocalDb.instance.database;
    final status = finalConfirm ? 'CONFIRMED' : 'UNCHECKED';
    await db.update('app_collection_master', {
      'status': status,
      'sync_status': 'Pending',
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'local_id = ? AND status <> ?', whereArgs: [collectionLocalId, 'CONFIRMED']);
  }

  Future<void> syncOneCollection(Map<String, dynamic> col) async {
    final db = await LocalDb.instance.database;
    final localId = '${col['local_id']}';
    final no = '${col['collection_no']}';
    await ApiClient.instance.post('collection_create_header', {
      'local_id': localId,
      'collection_no': no,
      'collection_date': col['collection_date'],
    });
    final lines = await getLines(localId);
    for (final line in lines) {
      await ApiClient.instance.post('collection_add', {
        'local_id': line['local_id'],
        'collection_no': no,
        'route_id': line['route_id'],
        'route_name': line['route_name'],
        'outlet_id': line['outlet_id'],
        'outlet_name': line['outlet_name'],
        'opening_balance': line['opening_balance'],
        'amount': line['amount'],
        'closing_balance': line['closing_balance'],
        'payment_type': line['payment_type'] ?? line['collection_channel'] ?? 'Cash',
        'collection_channel': line['collection_channel'] ?? line['payment_type'] ?? 'Cash',
        'ledger_id': line['ledger_id'],
        'ledger_name': line['ledger_name'],
        'remarks': line['remarks'],
      });
    }
    if ('${col['status']}' != 'Draft') {
      await ApiClient.instance.post('collection_confirm', {'collection_no': no, 'confirm_final': '${col['status']}' == 'CONFIRMED'});
    }
    await db.delete('app_collection_details', where: 'collection_local_id = ?', whereArgs: [localId]);
    await db.delete('app_collection_master', where: 'local_id = ?', whereArgs: [localId]);
  }
}
