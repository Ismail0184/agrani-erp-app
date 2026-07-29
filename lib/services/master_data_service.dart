import 'package:sqflite/sqflite.dart';
import '../core/api_client.dart';
import '../core/local_db.dart';
import '../models/item_model.dart';
import '../models/outlet_model.dart';
import '../models/route_model.dart';

class MasterDataService {
  MasterDataService._();
  static final MasterDataService instance = MasterDataService._();

  Future<void> downloadMasterData({bool silent = false}) async {
    final data = await ApiClient.instance.get('download_master');
    final db = await LocalDb.instance.database;
    final batch = db.batch();
    batch.delete('items');
    batch.delete('outlets');
    for (final raw in (data['items'] as List? ?? [])) {
      batch.insert('items', ItemModel.fromMap(Map<String, dynamic>.from(raw as Map)).toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    for (final raw in (data['outlets'] as List? ?? [])) {
      batch.insert('outlets', OutletModel.fromMap(Map<String, dynamic>.from(raw as Map)).toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<OutletModel>> outlets({int? routeId}) async {
    final db = await LocalDb.instance.database;
    final rows = await db.query(
      'outlets',
      where: routeId != null && routeId > 0 ? 'route_id = ?' : null,
      whereArgs: routeId != null && routeId > 0 ? [routeId] : null,
      orderBy: 'outlet_name ASC',
    );
    return rows.map(OutletModel.fromMap).toList();
  }

  Future<List<OutletRouteModel>> routesFromOutlets() async {
    final db = await LocalDb.instance.database;
    final rows = await db.rawQuery('''
      SELECT route_id, MAX(route_name) route_name
      FROM outlets
      WHERE IFNULL(route_id, 0) > 0
      GROUP BY route_id
      ORDER BY MAX(route_name) ASC
    ''');
    return rows
        .map((row) => OutletRouteModel.fromMap({
              'route_id': row['route_id'],
              'route_name': '${row['route_name'] ?? 'Route ${row['route_id']}'}',
            }))
        .toList();
  }

  Future<List<ItemModel>> items() async {
    final db = await LocalDb.instance.database;
    final rows = await db.query('items', orderBy: 'item_name ASC');
    return rows.map(ItemModel.fromMap).toList();
  }
}
