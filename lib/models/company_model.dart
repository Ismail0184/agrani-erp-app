class CompanyModel {
  final int companyId;
  final String companyName;
  final String companyAddress;

  const CompanyModel({required this.companyId, required this.companyName, this.companyAddress = ''});

  factory CompanyModel.fromMap(Map<String, dynamic> map) => CompanyModel(
        companyId: int.tryParse('${map['company_id'] ?? map['id'] ?? 0}') ?? 0,
        companyName: '${map['company_name'] ?? map['company_short_name'] ?? map['name'] ?? ''}',
        companyAddress: '${map['company_address'] ?? map['address'] ?? ''}',
      );
}
