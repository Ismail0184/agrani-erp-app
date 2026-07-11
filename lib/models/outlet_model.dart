class OutletModel {
  final int outletId;
  final String outletName;
  final String outletCode;
  final String address;

  const OutletModel({required this.outletId, required this.outletName, this.outletCode = '', this.address = ''});

  factory OutletModel.fromMap(Map<String, dynamic> map) => OutletModel(
        outletId: int.tryParse('${map['outlet_id']}') ?? 0,
        outletName: '${map['outlet_name'] ?? ''}',
        outletCode: '${map['outlet_code'] ?? ''}',
        address: '${map['address'] ?? ''}',
      );

  Map<String, dynamic> toMap() => {
        'outlet_id': outletId,
        'outlet_name': outletName,
        'outlet_code': outletCode,
        'address': address,
        'updated_at': DateTime.now().toIso8601String(),
      };
}
