import '../core/api_client.dart';
import '../models/ledger_model.dart';
import '../models/expense_vehicle_model.dart';

class ExpenseService {
  ExpenseService._();
  static final ExpenseService instance = ExpenseService._();

  Future<List<LedgerModel>> ledgers() async {
    final data = await ApiClient.instance.get('expense_ledger_list');
    return (data['rows'] as List? ?? [])
        .whereType<Map>()
        .map((row) => LedgerModel.fromMap(Map<String, dynamic>.from(row)))
        .where(
          (ledger) =>
              ledger.ledgerId.trim().isNotEmpty &&
              ledger.displayName.trim().isNotEmpty,
        )
        .toList();
  }

  Future<List<ExpenseVehicleModel>> vehicles() async {
    final data = await ApiClient.instance.get('expense_vehicle_list');
    return (data['rows'] as List? ?? [])
        .whereType<Map>()
        .map((row) => ExpenseVehicleModel.fromMap(Map<String, dynamic>.from(row)))
        .where((vehicle) => vehicle.id > 0 && vehicle.displayName.trim().isNotEmpty)
        .toList();
  }

  Future<List<Map<String, dynamic>>> latestVouchers() async {
    final data = await ApiClient.instance.get('expense_voucher_list');
    return (data['rows'] as List? ?? [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<String> nextVoucherNo() async {
    final data = await ApiClient.instance.get('expense_voucher_next_no');
    return '${data['voucher_no'] ?? ''}'.trim();
  }

  Future<Map<String, dynamic>> initiateVoucher({
    required String voucherNo,
    required String voucherDate,
  }) {
    return ApiClient.instance.post('expense_voucher_initiate', {
      'voucher_no': voucherNo,
      'voucher_date': voucherDate,
    });
  }

  Future<Map<String, dynamic>> voucherDetails(String voucherNo) {
    return ApiClient.instance.get(
      'expense_voucher_details',
      query: {'voucher_no': voucherNo},
    );
  }

  Future<Map<String, dynamic>> addLine({
    required String voucherNo,
    required String ledgerId,
    required String narration,
    required double amount,
    int vehicleId = 0,
  }) {
    return ApiClient.instance.post('expense_voucher_add_line', {
      'voucher_no': voucherNo,
      'ledger_id': ledgerId,
      'narration': narration,
      'amount': amount,
      'dr_amt': amount,
      'cr_amt': 0,
      'vehicle_id': vehicleId,
    });
  }

  Future<Map<String, dynamic>> deleteLine({
    required String voucherNo,
    required int lineId,
  }) {
    return ApiClient.instance.post('expense_voucher_delete_line', {
      'voucher_no': voucherNo,
      'line_id': lineId,
    });
  }

  Future<Map<String, dynamic>> confirmVoucher(String voucherNo) {
    return ApiClient.instance.post('expense_voucher_confirm', {
      'voucher_no': voucherNo,
    });
  }

  Future<void> cancelVoucher(String voucherNo) async {
    await ApiClient.instance.post('expense_voucher_cancel', {
      'voucher_no': voucherNo,
    });
  }

  // Kept for backward compatibility with older builds.
  Future<Map<String, dynamic>> createVoucher({
    required String voucherDate,
    required List<Map<String, dynamic>> lines,
  }) {
    return ApiClient.instance.post('expense_voucher_create', {
      'voucher_date': voucherDate,
      'lines': lines,
    });
  }
}
