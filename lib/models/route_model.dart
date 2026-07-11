class OutletRouteModel {
  final int routeId;
  final String routeName;
  final String customRouteId;
  final int companyId;

  const OutletRouteModel({
    required this.routeId,
    required this.routeName,
    required this.customRouteId,
    required this.companyId,
  });

  factory OutletRouteModel.fromMap(Map<String, dynamic> map) => OutletRouteModel(
        routeId: int.tryParse('${map['route_id'] ?? map['dealer_code'] ?? 0}') ?? 0,
        routeName: '${map['route_name'] ?? map['dealer_name_e'] ?? map['dealer_name'] ?? ''}',
        customRouteId: '${map['custom_route_id'] ?? map['dealer_custom_code'] ?? ''}',
        companyId: int.tryParse('${map['company_id'] ?? 0}') ?? 0,
      );

  String get displayName {
    if (customRouteId.trim().isEmpty) return routeName;
    if (routeName.trim().isEmpty) return customRouteId;
    return '$customRouteId - $routeName';
  }
}
