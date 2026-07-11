import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class LocalDb {
  LocalDb._();
  static final LocalDb instance = LocalDb._();
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final path = join(await getDatabasesPath(), 'agrani_mobile_erp.db');
    _db = await openDatabase(path, version: 5, onCreate: _create, onUpgrade: _upgrade);
    return _db!;
  }

  Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _create(db, newVersion);
      await _safeAddColumn(db, 'app_order_details', 'server_id INTEGER');
      await _safeAddColumn(db, 'app_order_details', 'updated_at TEXT');
      await _safeAddColumn(db, 'app_collection_details', 'server_id INTEGER');
      await _safeAddColumn(db, 'app_collection_details', 'updated_at TEXT');
    }
    if (oldVersion < 3) {
      await _safeAddColumn(db, 'attendance', 'auto_logout INTEGER DEFAULT 0');
    }
    if (oldVersion < 4) {
      await _safeAddColumn(db, 'app_collection_details', 'collection_channel TEXT');
      await _safeAddColumn(db, 'app_collection_details', 'ledger_id INTEGER');
      await _safeAddColumn(db, 'app_collection_details', 'ledger_name TEXT');
      await _safeAddColumn(db, 'outlet_pending', 'route_id INTEGER');
      await _safeAddColumn(db, 'outlet_pending', 'route_name TEXT');
      await _safeAddColumn(db, 'outlet_pending', 'route_section_id INTEGER');
      await _safeAddColumn(db, 'outlet_pending', 'route_section_name TEXT');
      await _safeAddColumn(db, 'outlet_pending', 'shop_image_path TEXT');
    }
    if (oldVersion < 5) {
      await _createAuditPendingTables(db);
    }
  }

  Future<void> _safeAddColumn(Database db, String table, String columnSql) async {
    try {
      await db.execute('ALTER TABLE $table ADD COLUMN $columnSql');
    } catch (_) {}
  }

  Future<void> _create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS session_info(
        id INTEGER PRIMARY KEY,
        key_name TEXT UNIQUE,
        value TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS items(
        item_id INTEGER PRIMARY KEY,
        item_name TEXT,
        item_code TEXT,
        sales_rate REAL DEFAULT 0,
        updated_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS outlets(
        outlet_id INTEGER PRIMARY KEY,
        outlet_name TEXT,
        outlet_code TEXT,
        address TEXT,
        updated_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS attendance(
        local_id TEXT PRIMARY KEY,
        server_id INTEGER,
        attendance_date TEXT,
        login_time TEXT,
        login_latitude REAL,
        login_longitude REAL,
        logout_time TEXT,
        logout_latitude REAL,
        logout_longitude REAL,
        total_working_minutes INTEGER,
        attendance_status TEXT,
        auto_logout INTEGER DEFAULT 0,
        sync_status TEXT DEFAULT 'Pending',
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS gps_tracking(
        local_id TEXT PRIMARY KEY,
        attendance_id INTEGER,
        tracking_date TEXT,
        tracking_time TEXT,
        latitude REAL,
        longitude REAL,
        accuracy REAL,
        speed REAL,
        battery_percent REAL,
        internet_status TEXT,
        gps_status TEXT,
        sync_status TEXT DEFAULT 'Pending',
        created_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_order_master(
        local_id TEXT PRIMARY KEY,
        server_id INTEGER,
        order_no TEXT,
        order_date TEXT,
        outlet_id INTEGER,
        outlet_name TEXT,
        total_qty REAL DEFAULT 0,
        total_amount REAL DEFAULT 0,
        status TEXT DEFAULT 'Draft',
        sync_status TEXT DEFAULT 'Pending',
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_order_details(
        local_id TEXT PRIMARY KEY,
        server_id INTEGER,
        order_local_id TEXT,
        order_no TEXT,
        item_id INTEGER,
        item_name TEXT,
        unit_price REAL,
        qty REAL,
        amount REAL,
        sync_status TEXT DEFAULT 'Pending',
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_collection_master(
        local_id TEXT PRIMARY KEY,
        server_id INTEGER,
        collection_no TEXT,
        collection_date TEXT,
        total_amount REAL DEFAULT 0,
        status TEXT DEFAULT 'Draft',
        sync_status TEXT DEFAULT 'Pending',
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_collection_details(
        local_id TEXT PRIMARY KEY,
        server_id INTEGER,
        collection_local_id TEXT,
        collection_no TEXT,
        outlet_id INTEGER,
        outlet_name TEXT,
        amount REAL,
        payment_type TEXT,
        collection_channel TEXT,
        ledger_id INTEGER,
        ledger_name TEXT,
        remarks TEXT,
        sync_status TEXT DEFAULT 'Pending',
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS outlet_pending(
        local_id TEXT PRIMARY KEY,
        outlet_name TEXT,
        owner_name TEXT,
        mobile_no TEXT,
        address TEXT,
        route_id INTEGER,
        route_name TEXT,
        route_section_id INTEGER,
        route_section_name TEXT,
        shop_image_path TEXT,
        latitude REAL,
        longitude REAL,
        status TEXT DEFAULT 'PENDING',
        sync_status TEXT DEFAULT 'Pending',
        created_at TEXT
      )
    ''');
    await _createAuditPendingTables(db);
  }

  Future<void> _createAuditPendingTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS audit_checklist_pending_actions(
        local_id TEXT PRIMARY KEY,
        action TEXT,
        payload TEXT,
        sync_status TEXT DEFAULT 'Pending',
        created_at TEXT
      )
    ''');
  }

  Future<int> pendingCount() async {
    final db = await database;
    final tables = ['attendance', 'gps_tracking', 'app_order_master', 'app_order_details', 'app_collection_master', 'app_collection_details', 'outlet_pending', 'audit_checklist_pending_actions'];
    int total = 0;
    for (final t in tables) {
      final row = await db.rawQuery("SELECT COUNT(*) c FROM $t WHERE IFNULL(sync_status,'Pending') <> 'Synced'");
      total += (row.first['c'] as int?) ?? 0;
    }
    return total;
  }

  Future<Map<String, dynamic>?> todayAttendance() async {
    final db = await database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final rows = await db.query('attendance', where: 'attendance_date = ?', whereArgs: [today], orderBy: 'login_time ASC', limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, int>> dashboardCounts() async {
    final db = await database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    Future<int> count(String sql, List<Object?> args) async {
      final row = await db.rawQuery(sql, args);
      return (row.first['c'] as int?) ?? 0;
    }

    return {
      'todayOrders': await count('SELECT COUNT(*) c FROM app_order_master WHERE order_date = ?', [today]),
      'uncheckedOrders': await count("SELECT COUNT(*) c FROM app_order_master WHERE status = 'UNCHECKED'", []),
      'todayCollections': await count('SELECT COUNT(*) c FROM app_collection_master WHERE collection_date = ?', [today]),
      'pendingSync': await pendingCount(),
    };
  }

  Future<void> recalcOrder(String orderLocalId) async {
    final db = await database;
    final row = await db.rawQuery('SELECT IFNULL(SUM(qty),0) qty, IFNULL(SUM(amount),0) amount FROM app_order_details WHERE order_local_id = ?', [orderLocalId]);
    await db.update('app_order_master', {
      'total_qty': (row.first['qty'] as num?)?.toDouble() ?? 0,
      'total_amount': (row.first['amount'] as num?)?.toDouble() ?? 0,
      'sync_status': 'Pending',
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'local_id = ?', whereArgs: [orderLocalId]);
  }

  Future<void> recalcCollection(String collectionLocalId) async {
    final db = await database;
    final row = await db.rawQuery('SELECT IFNULL(SUM(amount),0) amount FROM app_collection_details WHERE collection_local_id = ?', [collectionLocalId]);
    await db.update('app_collection_master', {
      'total_amount': (row.first['amount'] as num?)?.toDouble() ?? 0,
      'sync_status': 'Pending',
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'local_id = ?', whereArgs: [collectionLocalId]);
  }
}
