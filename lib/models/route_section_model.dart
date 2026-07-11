class RouteSectionModel {
  final int id;
  final int routeId;
  final String sectionName;
  final int sectionId;

  const RouteSectionModel({
    required this.id,
    required this.routeId,
    required this.sectionName,
    required this.sectionId,
  });

  factory RouteSectionModel.fromMap(Map<String, dynamic> map) => RouteSectionModel(
        id: int.tryParse('${map['id'] ?? map['route_section_id'] ?? 0}') ?? 0,
        routeId: int.tryParse('${map['route_id'] ?? 0}') ?? 0,
        sectionName: '${map['route_section_name'] ?? map['section_name'] ?? ''}',
        sectionId: int.tryParse('${map['section_id'] ?? 0}') ?? 0,
      );
}
