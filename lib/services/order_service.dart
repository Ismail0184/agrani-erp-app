import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../core/api_client.dart';
import '../core/local_db.dart';
import '../models/item_model.dart';
import '../models/outlet_model.dart';

class OrderService {
  OrderService._();
  static final OrderService instance = OrderService._();
  final _uuid = const Uuid();

  String _newOrderNo() => 'ORD-${DateTime.now().millisecondsSinceEpoch}';
  bool _isServerId(String id) => id.startsWith('server:');
  bool _isServerLineId(String id) => id.startsWith('server_detail:');
  String _serverNo(String id) => id.replaceFirst('server:', '');
  int _serverDetailId(String id) => int.tryParse(id.replaceFirst('server_detail:', '')) ?? 0;

  Future<List<Map<String, dynamic>>> listOrders({
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
      final data = await ApiClient.instance.get('order_list', query: {
        if (from != null && from.isNotEmpty) 'from': from,
        if (to != null && to.isNotEmpty) 'to': to,
        if (outletId != null && outletId > 0) 'outlet_id': '$outletId',
        if (status != null && status.isNotEmpty) 'status': status,
        'limit': '300',
      });
      for (final raw in (data['rows'] as List? ?? [])) {
        final row = Map<String, dynamic>.from(raw as Map);
        row['server_id'] = row['id'];
        row['local_id'] = 'server:${row['order_no']}';
        row['source'] = 'online';
        result.add(row);
      }
    } catch (_) {
      if (onlineOnly) return result;
    }

    if (!onlineOnly && includeLocalPending) {
      final where = <String>[];
      final args = <Object?>[];
      if (from != null && from.isNotEmpty) { where.add('order_date >= ?'); args.add(from); }
      if (to != null && to.isNotEmpty) { where.add('order_date <= ?'); args.add(to); }
      if (outletId != null && outletId > 0) { where.add('outlet_id = ?'); args.add(outletId); }
      if (status != null && status.isNotEmpty) { where.add('status = ?'); args.add(status); }
      where.add("IFNULL(sync_status,'Pending') <> 'Synced'");
      final localRows = await db.query('app_order_master', where: where.join(' AND '), whereArgs: args, orderBy: 'created_at DESC');
      for (final r in localRows) {
        final row = Map<String, dynamic>.from(r);
        row['source'] = 'local';
        result.insert(0, row);
      }
    }
    return result;
  }

  Future<double> outletCurrentBalance(int outletId) async {
    final data = await ApiClient.instance.get('outlet_current_balance', query: {'outlet_id': '$outletId'});
    return double.tryParse('${data['opening_balance'] ?? 0}') ?? 0;
  }

  Future<String> createHeader({required String orderDate, required OutletModel outlet}) async {
    final db = await LocalDb.instance.database;
    final localId = _uuid.v4();
    await db.insert('app_order_master', {
      'local_id': localId,
      'order_no': _newOrderNo(),
      'order_date': orderDate,
      'outlet_id': outlet.outletId,
      'outlet_name': outlet.outletName,
      'status': 'Draft',
      'sync_status': 'Pending',
      'created_at': DateTime.now().toIso8601String(),
    });
    return localId;
  }

  Future<void> addItem({required String orderLocalId, required String orderNo, required ItemModel item, required double qty, required double rate}) async {
    final db = await LocalDb.instance.database;
    final amount = qty * rate;
    await db.insert('app_order_details', {
      'local_id': _uuid.v4(),
      'order_local_id': orderLocalId,
      'order_no': orderNo,
      'item_id': item.itemId,
      'item_name': item.itemName,
      'unit_price': rate,
      'qty': qty,
      'amount': amount,
      'sync_status': 'Pending',
      'created_at': DateTime.now().toIso8601String(),
    });
    await LocalDb.instance.recalcOrder(orderLocalId);
  }

  Future<Map<String, dynamic>?> getOrder(String localId) async {
    if (_isServerId(localId)) {
      final orderNo = _serverNo(localId);
      final data = await ApiClient.instance.get('order_details', query: {'order_no': orderNo});
      final row = Map<String, dynamic>.from(data['order'] as Map);
      row['server_id'] = row['id'];
      row['local_id'] = localId;
      row['source'] = 'online';
      return row;
    }
    final db = await LocalDb.instance.database;
    final rows = await db.query('app_order_master', where: 'local_id = ?', whereArgs: [localId], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> getItems(String orderLocalId) async {
    if (_isServerId(orderLocalId)) {
      final orderNo = _serverNo(orderLocalId);
      final data = await ApiClient.instance.get('order_details', query: {'order_no': orderNo});
      final items = <Map<String, dynamic>>[];
      for (final raw in (data['items'] as List? ?? [])) {
        final row = Map<String, dynamic>.from(raw as Map);
        row['server_id'] = row['id'];
        row['local_id'] = 'server_detail:${row['id']}';
        row['source'] = 'online';
        items.add(row);
      }
      return items;
    }
    final db = await LocalDb.instance.database;
    return db.query('app_order_details', where: 'order_local_id = ?', whereArgs: [orderLocalId], orderBy: 'created_at ASC');
  }

  Future<void> updateLine({required String lineLocalId, required double qty, required double rate}) async {
    if (_isServerLineId(lineLocalId)) {
      await ApiClient.instance.post('order_line_update', {
        'detail_id': _serverDetailId(lineLocalId),
        'qty': qty,
        'unit_price': rate,
      });
      return;
    }
    final db = await LocalDb.instance.database;
    final rows = await db.query('app_order_details', where: 'local_id = ?', whereArgs: [lineLocalId], limit: 1);
    if (rows.isEmpty) return;
    final orderLocalId = '${rows.first['order_local_id']}';
    await db.update('app_order_details', {
      'qty': qty,
      'unit_price': rate,
      'amount': qty * rate,
      'sync_status': 'Pending',
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'local_id = ?', whereArgs: [lineLocalId]);
    await LocalDb.instance.recalcOrder(orderLocalId);
  }

  Future<void> deleteLine(String lineLocalId) async {
    if (_isServerLineId(lineLocalId)) {
      await ApiClient.instance.post('order_line_delete', {'detail_id': _serverDetailId(lineLocalId)});
      return;
    }
    final db = await LocalDb.instance.database;
    final rows = await db.query('app_order_details', where: 'local_id = ?', whereArgs: [lineLocalId], limit: 1);
    if (rows.isEmpty) return;
    final orderLocalId = '${rows.first['order_local_id']}';
    await db.delete('app_order_details', where: 'local_id = ?', whereArgs: [lineLocalId]);
    await LocalDb.instance.recalcOrder(orderLocalId);
  }

  Future<void> deleteOrder(String orderLocalId) async {
    if (_isServerId(orderLocalId)) {
      await ApiClient.instance.post('order_cancel', {'order_no': _serverNo(orderLocalId)});
      return;
    }
    final db = await LocalDb.instance.database;
    await db.delete('app_order_details', where: 'order_local_id = ?', whereArgs: [orderLocalId]);
    await db.delete('app_order_master', where: 'local_id = ?', whereArgs: [orderLocalId]);
  }

  Future<void> submitOrder(String orderLocalId, {bool finalConfirm = false}) async {
    if (_isServerId(orderLocalId)) {
      await ApiClient.instance.post('order_confirm', {'order_no': _serverNo(orderLocalId), 'confirm_final': finalConfirm});
      return;
    }
    final db = await LocalDb.instance.database;
    final status = finalConfirm ? 'CONFIRMED' : 'UNCHECKED';
    await db.update('app_order_master', {
      'status': status,
      'sync_status': 'Pending',
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'local_id = ? AND status <> ?', whereArgs: [orderLocalId, 'CONFIRMED']);
  }

  Future<void> syncOneOrder(Map<String, dynamic> order) async {
    final db = await LocalDb.instance.database;
    final localId = '${order['local_id']}';
    final orderNo = '${order['order_no']}';
    await ApiClient.instance.post('order_create_header', {
      'local_id': localId,
      'order_no': orderNo,
      'order_date': order['order_date'],
      'outlet_id': order['outlet_id'],
      'outlet_name': order['outlet_name'],
    });
    final lines = await getItems(localId);
    for (final line in lines) {
      await ApiClient.instance.post('order_add_item', {
        'local_id': line['local_id'],
        'order_no': orderNo,
        'item_id': line['item_id'],
        'item_name': line['item_name'],
        'unit_price': line['unit_price'],
        'qty': line['qty'],
      });
    }
    if ('${order['status']}' != 'Draft') {
      await ApiClient.instance.post('order_confirm', {'order_no': orderNo, 'confirm_final': '${order['status']}' == 'CONFIRMED'});
    }
    await db.delete('app_order_details', where: 'order_local_id = ?', whereArgs: [localId]);
    await db.delete('app_order_master', where: 'local_id = ?', whereArgs: [localId]);
  }
}
