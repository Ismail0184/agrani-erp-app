class ExpenseVehicleModel {
  final int id;
  final String name;
  final String registrationNo;
  final String vehicleTypeName;

  const ExpenseVehicleModel({
    required this.id,
    required this.name,
    this.registrationNo = '',
    this.vehicleTypeName = '',
  });

  factory ExpenseVehicleModel.fromMap(Map<String, dynamic> map) => ExpenseVehicleModel(
        id: int.tryParse('${map['id'] ?? map['vehicle_id'] ?? 0}') ?? 0,
        name: '${map['name'] ?? map['vehicle_name'] ?? ''}'.trim(),
        registrationNo: '${map['registration_no'] ?? ''}'.trim(),
        vehicleTypeName: '${map['vehicle_type_name'] ?? ''}'.trim(),
      );

  String get displayName {
    if (name.isNotEmpty) return name;
    if (registrationNo.isEmpty) return '$id';
    if (vehicleTypeName.isEmpty) return registrationNo;
    return '$registrationNo : $vehicleTypeName';
  }
}
