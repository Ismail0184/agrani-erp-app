class OutletMasterModel {
  final int outletId;
  final String outletCode;
  final int territoryId;
  final String territoryName;
  final int routeId;
  final String routeName;
  final int routeSectionId;
  final String routeSectionName;
  final String outletImage;
  final String marketName;
  final String outletName;
  final String ownerName;
  final String contactNumber;
  final String shopAddress;
  final double? latitude;
  final double? longitude;
  final String status;
  final String entryAt;
  final String locationText;

  const OutletMasterModel({
    required this.outletId,
    required this.outletCode,
    required this.territoryId,
    required this.territoryName,
    required this.routeId,
    required this.routeName,
    required this.routeSectionId,
    required this.routeSectionName,
    required this.outletImage,
    required this.marketName,
    required this.outletName,
    required this.ownerName,
    required this.contactNumber,
    required this.shopAddress,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.entryAt,
    required this.locationText,
  });

  factory OutletMasterModel.fromMap(Map<String, dynamic> map) => OutletMasterModel(
        outletId: int.tryParse('${map['outlet_id']}') ?? 0,
        outletCode: '${map['outlet_code'] ?? ''}',
        territoryId: int.tryParse('${map['territory_id'] ?? 0}') ?? 0,
        territoryName: '${map['territory_name'] ?? map['territory'] ?? ''}',
        routeId: int.tryParse('${map['route_id'] ?? 0}') ?? 0,
        routeName: '${map['route_name'] ?? map['route'] ?? ''}',
        routeSectionId: int.tryParse('${map['route_section_id'] ?? 0}') ?? 0,
        routeSectionName: '${map['route_section_name'] ?? map['route_sec'] ?? map['section'] ?? ''}',
        outletImage: '${map['outlet_image'] ?? map['shop_image'] ?? ''}',
        marketName: '${map['market_name'] ?? ''}',
        outletName: '${map['outlet_name'] ?? ''}',
        ownerName: '${map['owner_name'] ?? ''}',
        contactNumber: '${map['contact_number'] ?? ''}',
        shopAddress: '${map['cluster_name'] ?? map['shop_address'] ?? ''}',
        latitude: double.tryParse('${map['latitude'] ?? ''}'),
        longitude: double.tryParse('${map['longitude'] ?? ''}'),
        status: '${map['status'] ?? 'PENDING'}',
        entryAt: '${map['entry_at'] ?? ''}',
        locationText: '${map['map_location_text'] ?? map['location_text'] ?? ''}',
      );

  String get latLngText {
    if (latitude == null || longitude == null) return '-';
    return '${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}';
  }
}
