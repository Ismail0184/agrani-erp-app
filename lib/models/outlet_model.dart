class OutletModel {
  final int outletId;
  final String outletName;
  final String outletCode;
  final String address;
  final int routeId;
  final String routeName;

  const OutletModel({
    required this.outletId,
    required this.outletName,
    this.outletCode = '',
    this.address = '',
    this.routeId = 0,
    this.routeName = '',
  });

  factory OutletModel.fromMap(Map<String, dynamic> map) => OutletModel(
        outletId: int.tryParse('${map['outlet_id']}') ?? 0,
        outletName: '${map['outlet_name'] ?? ''}',
        outletCode: '${map['outlet_code'] ?? ''}',
        address: '${map['address'] ?? ''}',
        routeId: int.tryParse('${map['route_id'] ?? 0}') ?? 0,
        routeName: '${map['route_name'] ?? ''}',
      );

  Map<String, dynamic> toMap() => {
        'outlet_id': outletId,
        'outlet_name': outletName,
        'outlet_code': outletCode,
        'address': address,
        'route_id': routeId,
        'route_name': routeName,
        'updated_at': DateTime.now().toIso8601String(),
      };
}
