import 'package:sqflite/sqflite.dart';
import '../core/api_client.dart';
import '../core/local_db.dart';
import '../models/item_model.dart';
import '../models/outlet_model.dart';

class MasterDataService {
  MasterDataService._();
  static final MasterDataService instance = MasterDataService._();

  Future<void> downloadMasterData({bool silent = false}) async {
    final data = await ApiClient.instance.get('download_master');
    final db = await LocalDb.instance.database;
    final batch = db.batch();
    for (final raw in (data['items'] as List? ?? [])) {
      batch.insert('items', ItemModel.fromMap(Map<String, dynamic>.from(raw as Map)).toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    for (final raw in (data['outlets'] as List? ?? [])) {
      batch.insert('outlets', OutletModel.fromMap(Map<String, dynamic>.from(raw as Map)).toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<OutletModel>> outlets() async {
    final db = await LocalDb.instance.database;
    final rows = await db.query('outlets', orderBy: 'outlet_name ASC');
    return rows.map(OutletModel.fromMap).toList();
  }

  Future<List<ItemModel>> items() async {
    final db = await LocalDb.instance.database;
    final rows = await db.query('items', orderBy: 'item_name ASC');
    return rows.map(ItemModel.fromMap).toList();
  }
}
