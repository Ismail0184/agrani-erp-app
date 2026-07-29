import '../core/api_client.dart';

class DeliveryService {
  DeliveryService._();
  static final DeliveryService instance = DeliveryService._();

  Future<List<Map<String, dynamic>>> pendingOrders() async {
    final data = await ApiClient.instance.get('pending_delivery_list');
    return (data['rows'] as List? ?? [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<Map<String, dynamic>> orderDetails(String orderNo) async {
    final data = await ApiClient.instance.get(
      'pending_delivery_details',
      query: {'order_no': orderNo},
    );
    final rawOrder = data['order'];
    return {
      'order': rawOrder is Map
          ? Map<String, dynamic>.from(rawOrder)
          : <String, dynamic>{},
      'items': (data['items'] as List? ?? [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(),
    };
  }

  Future<Map<String, dynamic>> confirmDelivery({
    required String orderNo,
    required bool closeOrder,
    required List<Map<String, dynamic>> items,
  }) async {
    return ApiClient.instance.post('pending_delivery_confirm', {
      'order_no': orderNo,
      'close_order': closeOrder,
      'items': items,
    });
  }
}
