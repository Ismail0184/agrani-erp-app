class TerritoryModel {
  final int id;
  final String territoryName;

  const TerritoryModel({required this.id, required this.territoryName});

  factory TerritoryModel.fromMap(Map<String, dynamic> map) => TerritoryModel(
        id: int.tryParse('${map['id']}') ?? 0,
        territoryName: '${map['territory_name'] ?? ''}',
      );
}
