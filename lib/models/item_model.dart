import '../core/bangladesh_time.dart';
class ItemModel {
  final int itemId;
  final String itemName;
  final String itemCode;
  final double salesRate;

  const ItemModel({required this.itemId, required this.itemName, this.itemCode = '', this.salesRate = 0});

  factory ItemModel.fromMap(Map<String, dynamic> map) => ItemModel(
        itemId: int.tryParse('${map['item_id']}') ?? 0,
        itemName: '${map['item_name'] ?? ''}',
        itemCode: '${map['item_code'] ?? ''}',
        salesRate: double.tryParse('${map['sales_rate'] ?? 0}') ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'item_id': itemId,
        'item_name': itemName,
        'item_code': itemCode,
        'sales_rate': salesRate,
        'updated_at': BangladeshTime.isoLocal(),
      };
}
