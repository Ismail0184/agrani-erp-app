class CollectionLedgerModel {
  final int ledgerId;
  final String ledgerName;
  final String ledgerCode;
  final String channel;

  const CollectionLedgerModel({
    required this.ledgerId,
    required this.ledgerName,
    required this.ledgerCode,
    required this.channel,
  });

  factory CollectionLedgerModel.fromMap(Map<String, dynamic> map) => CollectionLedgerModel(
        ledgerId: int.tryParse('${map['ledger_id'] ?? map['id'] ?? map['account_code'] ?? 0}') ?? 0,
        ledgerName: '${map['ledger_name'] ?? map['ledger_name_e'] ?? map['account_name'] ?? map['name'] ?? ''}',
        ledgerCode: '${map['ledger_code'] ?? map['account_code'] ?? map['ledger_id'] ?? ''}',
        channel: '${map['channel'] ?? map['collection_channel'] ?? ''}',
      );

  String get displayName {
    if (ledgerCode.trim().isEmpty) return ledgerName;
    if (ledgerName.trim().isEmpty) return ledgerCode;
    return '$ledgerCode - $ledgerName';
  }
}
