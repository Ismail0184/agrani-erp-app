class LedgerModel {
  final String ledgerId;
  final String ledgerName;
  final String ledgerCode;

  const LedgerModel({
    required this.ledgerId,
    required this.ledgerName,
    this.ledgerCode = '',
  });

  factory LedgerModel.fromMap(Map<String, dynamic> map) => LedgerModel(
        ledgerId: '${map['ledger_id'] ?? map['id'] ?? ''}',
        ledgerName: '${map['ledger_name'] ?? map['name'] ?? ''}',
        ledgerCode: '${map['ledger_code'] ?? map['ledger_id'] ?? ''}',
      );

  String get displayName {
    final id = ledgerId.trim();
    final name = ledgerName.trim();
    if (id.isEmpty) return name;
    if (name.isEmpty) return id;
    return '$id : $name';
  }
}
