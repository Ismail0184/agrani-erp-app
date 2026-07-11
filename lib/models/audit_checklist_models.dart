class AuditChecklistGroupModel {
  final int groupId;
  final String groupEnName;
  final String groupBnName;

  const AuditChecklistGroupModel({required this.groupId, required this.groupEnName, required this.groupBnName});

  factory AuditChecklistGroupModel.fromMap(Map<String, dynamic> map) => AuditChecklistGroupModel(
        groupId: int.tryParse('${map['group_id'] ?? 0}') ?? 0,
        groupEnName: '${map['group_en_name'] ?? ''}',
        groupBnName: '${map['group_bn_name'] ?? map['sub_group_bn_name'] ?? ''}',
      );

  String get displayName => groupBnName.trim().isNotEmpty ? groupBnName : groupEnName;
}

class AuditChecklistSubGroupModel {
  final int subGroupId;
  final int groupId;
  final String subGroupEnName;
  final String subGroupBnName;

  const AuditChecklistSubGroupModel({
    required this.subGroupId,
    required this.groupId,
    required this.subGroupEnName,
    required this.subGroupBnName,
  });

  factory AuditChecklistSubGroupModel.fromMap(Map<String, dynamic> map) => AuditChecklistSubGroupModel(
        subGroupId: int.tryParse('${map['sub_group_id'] ?? 0}') ?? 0,
        groupId: int.tryParse('${map['group_id'] ?? 0}') ?? 0,
        subGroupEnName: '${map['sub_group_en_name'] ?? ''}',
        subGroupBnName: '${map['sub_group_bn_name'] ?? ''}',
      );

  String get displayName => subGroupBnName.trim().isNotEmpty ? subGroupBnName : subGroupEnName;
  bool get isOthers {
    final text = displayName.toLowerCase().trim();
    return text.contains('other') || text.contains('others') || displayName.contains('অন্যান্য');
  }
}

class AuditChecklistMasterModel {
  final int id;
  final String date;
  final int companyId;
  final String companyName;
  final String status;
  final String entryAt;
  final int totalDetails;

  const AuditChecklistMasterModel({
    required this.id,
    required this.date,
    required this.companyId,
    required this.companyName,
    required this.status,
    required this.entryAt,
    required this.totalDetails,
  });

  factory AuditChecklistMasterModel.fromMap(Map<String, dynamic> map) => AuditChecklistMasterModel(
        id: int.tryParse('${map['id'] ?? 0}') ?? 0,
        date: '${map['date'] ?? ''}',
        companyId: int.tryParse('${map['company_id'] ?? 0}') ?? 0,
        companyName: '${map['company_name'] ?? ''}',
        status: '${map['status'] ?? 'DRAFTED'}',
        entryAt: '${map['entry_at'] ?? ''}',
        totalDetails: int.tryParse('${map['total_details'] ?? 0}') ?? 0,
      );

  bool get editable => status.toUpperCase() != 'CHECKED' && status.toUpperCase() != 'APPROVED';
}

class AuditChecklistDetailModel {
  final int id;
  final int masterId;
  final int groupId;
  final String groupName;
  final int subGroupId;
  final String subGroupName;
  final String statusValue;
  final String remarks;
  final String value;
  final String othersText;
  final String attachmentUrl;
  final String entryAt;

  const AuditChecklistDetailModel({
    required this.id,
    required this.masterId,
    required this.groupId,
    required this.groupName,
    required this.subGroupId,
    required this.subGroupName,
    required this.statusValue,
    required this.remarks,
    required this.value,
    this.othersText = '',
    this.attachmentUrl = '',
    required this.entryAt,
  });

  factory AuditChecklistDetailModel.fromMap(Map<String, dynamic> map) => AuditChecklistDetailModel(
        id: int.tryParse('${map['id'] ?? 0}') ?? 0,
        masterId: int.tryParse('${map['master_id'] ?? 0}') ?? 0,
        groupId: int.tryParse('${map['group_id'] ?? 0}') ?? 0,
        groupName: '${map['group_name'] ?? map['group_bn_name'] ?? ''}',
        subGroupId: int.tryParse('${map['sub_group_id'] ?? 0}') ?? 0,
        subGroupName: '${map['sub_group_name'] ?? map['sub_group_bn_name'] ?? ''}',
        statusValue: '${map['status_value'] ?? map['check_status'] ?? ''}',
        remarks: '${map['remarks'] ?? ''}',
        value: '${map['value'] ?? ''}',
        othersText: '${map['others_text'] ?? ''}',
        attachmentUrl: '${map['attachment_url'] ?? ''}',
        entryAt: '${map['entry_at'] ?? ''}',
      );
}
