import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import '../core/bangladesh_time.dart';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import '../core/app_theme.dart';
import '../models/audit_checklist_models.dart';
import '../models/company_model.dart';
import '../services/audit_checklist_service.dart';
import '../widgets/pro_widgets.dart';
import 'audit_denomination_sheet_page.dart';

class AuditChecklistCreatePage extends StatefulWidget {
  final int? existingMasterId;
  final String? existingBranchName;

  const AuditChecklistCreatePage({super.key, this.existingMasterId, this.existingBranchName});

  @override
  State<AuditChecklistCreatePage> createState() => _AuditChecklistCreatePageState();
}

class _AuditChecklistCreatePageState extends State<AuditChecklistCreatePage> {
  final _remarks = TextEditingController();
  final _value = TextEditingController();
  final _others = TextEditingController();
  final _picker = ImagePicker();
  String _attachmentPath = '';

  List<CompanyModel> branches = [];
  List<AuditChecklistGroupModel> groups = [];
  List<AuditChecklistSubGroupModel> subGroups = [];
  List<AuditChecklistDetailModel> details = [];

  CompanyModel? branch;
  AuditChecklistMasterModel? master;
  AuditChecklistGroupModel? group;
  AuditChecklistSubGroupModel? subGroup;
  String? statusValue;

  bool loading = true;
  bool initiating = false;
  bool detailLoading = false;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _loadBranches();
    if (widget.existingMasterId != null && widget.existingMasterId! > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadExistingSession());
    }
  }

  Future<void> _loadExistingSession() async {
    final id = widget.existingMasterId;
    if (id == null || id <= 0) return;

    setState(() => loading = true);
    try {
      master = AuditChecklistMasterModel(
        id: id,
        date: '',
        companyId: 0,
        companyName: widget.existingBranchName ?? '',
        status: 'UNCHECKED',
        entryAt: '',
        totalDetails: 0,
      );
      await _reloadAfterInitiate();
    } catch (e) {
      if (mounted) _show('Existing checklist load failed: $e', error: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    _remarks.dispose();
    _value.dispose();
    _others.dispose();
    super.dispose();
  }

  Future<void> _loadBranches() async {
    setState(() => loading = true);
    try {
      branches = await AuditChecklistService.instance.branches();
    } catch (e) {
      if (mounted) _show('Branch load failed: $e', error: true);
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _initiate() async {
    if (branch == null) {
      _show('Please select branch first.', error: true);
      return;
    }
    setState(() => initiating = true);
    try {
      master = await AuditChecklistService.instance.initiate(branch!);
      await _reloadAfterInitiate();
      if (mounted) _show('Checklist initiated successfully');
    } catch (e) {
      if (mounted) _show('Initiate failed: $e', error: true);
    }
    if (mounted) setState(() => initiating = false);
  }

  Future<void> _reloadAfterInitiate() async {
    if (master == null) return;
    groups = await AuditChecklistService.instance.groups(master!.id);
    details = await AuditChecklistService.instance.details(master!.id);
    setState(() {});
  }

  Future<void> _loadSubGroups(AuditChecklistGroupModel g) async {
    if (master == null) return;
    setState(() {
      group = g;
      subGroup = null;
      subGroups = [];
      detailLoading = true;
    });

    try {
      subGroups = await AuditChecklistService.instance.subGroups(masterId: master!.id, groupId: g.groupId);
    } catch (e) {
      if (mounted) _show('Sub group load failed: $e', error: true);
    }
    if (mounted) setState(() => detailLoading = false);
  }

  Future<void> _selectSubGroup(AuditChecklistSubGroupModel? s) async {
    if (s == null) {
      setState(() {
        subGroup = null;
        _others.clear();
      });
      return;
    }

    setState(() {
      subGroup = s;
      _others.clear();
    });

    // Denomination sheet will open only for group_id = 2 and sub_group_id = 6.
    if (group?.groupId == 2 && s.subGroupId == 6) {
      await _openDenominationSheet();
    }
  }

  Future<void> _openDenominationSheet() async {
    if (master == null) return;
    final denGroup = group;
    final denSubGroup = subGroup;

    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AuditDenominationSheetPage(masterId: master!.id)),
    );

    if (saved == true) {
      final completedGroup = denGroup;
      final completedSubGroup = denSubGroup;

      await _reloadAfterInitiate();

      // Denomination data is saved in a separate table. Show it in Step 3 as
      // subgroup 6, then remove only subgroup 6 from the current subgroup list.
      // The full group will disappear naturally only when all active subgroups
      // under that group are completed by the API response.
      final hasDenominationRow = details.any(
        (d) => d.groupId == 2 && (d.subGroupId == 6 || d.subGroupName.toLowerCase().contains('denomination')),
      );
      if (!hasDenominationRow) {
        details.add(AuditChecklistDetailModel(
          id: 0,
          masterId: master!.id,
          groupId: completedGroup?.groupId ?? 2,
          groupName: completedGroup?.displayName ?? 'Denomination',
          subGroupId: completedSubGroup?.subGroupId ?? 6,
          subGroupName: completedSubGroup?.displayName ?? 'Denomination Sheet',
          statusValue: 'Yes',
          remarks: 'Denomination sheet saved.',
          value: '',
          entryAt: BangladeshTime.isoLocal(),
        ));
      }

      if (completedGroup != null && group?.groupId == completedGroup.groupId) {
        subGroups.removeWhere((e) => e.subGroupId == (completedSubGroup?.subGroupId ?? 6));
        if (subGroups.isEmpty) {
          group = null;
        } else {
          group = completedGroup;
        }
      } else {
        group = null;
        subGroups = [];
      }
      subGroup = null;

      if (mounted) {
        setState(() {});
        _show('Denomination sheet added');
      }
    }
  }

  Future<void> _pickAttachment(ImageSource source) async {
    try {
      // Keep the selected image size moderate to avoid low-memory crash during crop.
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (file == null) return;

      String selectedPath = file.path;

      // Native crop screens can place the OK button outside the reachable area
      // on some phones. This project now uses a responsive Flutter crop screen
      // with bottom fixed Confirm/Use Original buttons.
      final croppedPath = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => _AuditAttachmentCropPage(imagePath: file.path)),
      );

      if (croppedPath != null && croppedPath.trim().isNotEmpty) {
        selectedPath = croppedPath;
      }

      if (!mounted) return;
      setState(() => _attachmentPath = selectedPath);
    } catch (e) {
      if (mounted) _show('Image selection failed: $e', error: true);
    }
  }

  Future<void> _chooseAttachment() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_camera_rounded), title: const Text('Take Photo'), onTap: () => Navigator.pop(context, ImageSource.camera)),
          ListTile(leading: const Icon(Icons.photo_library_rounded), title: const Text('Select from Gallery'), onTap: () => Navigator.pop(context, ImageSource.gallery)),
        ]),
      ),
    );
    if (source != null) await _pickAttachment(source);
  }



  void _openAttachment(AuditChecklistDetailModel d) {
    final path = d.attachmentUrl.trim();
    if (path.isEmpty) return;

    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              color: AppColors.primary,
              child: Row(children: [
                const Icon(Icons.attachment_rounded, color: Colors.white),
                const SizedBox(width: 8),
                const Expanded(child: Text('Attachment Preview', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: Colors.white)),
              ]),
            ),
            Flexible(
              child: InteractiveViewer(
                minScale: .7,
                maxScale: 4,
                child: _attachmentPreview(path),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _attachmentPreview(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) => progress == null ? child : const Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()),
        errorBuilder: (_, __, ___) => const Padding(padding: EdgeInsets.all(24), child: Text('Attachment image could not be loaded.')),
      );
    }

    final file = File(path);
    if (file.existsSync()) return Image.file(file, fit: BoxFit.contain);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Text(path, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }

  Future<void> _submitDetail() async {
    if (master == null || group == null || subGroup == null || statusValue == null) {
      _show('Group, sub group and status are required.', error: true);
      return;
    }
    setState(() => saving = true);
    try {
      final selectedGroup = group!;
      final selectedSubGroup = subGroup!;
      final selectedStatus = statusValue!;
      final enteredRemarks = _remarks.text.trim();
      final enteredValue = _value.text.trim();
      final enteredOthers = _others.text.trim();
      final enteredAttachmentPath = _attachmentPath.trim();

      if (selectedSubGroup.isOthers && enteredOthers.isEmpty) {
        _show('Please enter Others details/specification.', error: true);
        setState(() => saving = false);
        return;
      }

      final queued = await AuditChecklistService.instance.saveDetail(
        masterId: master!.id,
        group: selectedGroup,
        subGroup: selectedSubGroup,
        statusValue: selectedStatus,
        remarks: enteredRemarks,
        value: enteredValue,
        othersText: enteredOthers,
        attachmentPath: enteredAttachmentPath,
      );

      _remarks.clear();
      _value.clear();
      _others.clear();
      _attachmentPath = '';
      statusValue = null;
      subGroup = null;

      if (queued) {
        details.add(AuditChecklistDetailModel(
          id: -DateTime.now().microsecondsSinceEpoch,
          masterId: master!.id,
          groupId: selectedGroup.groupId,
          groupName: selectedGroup.displayName,
          subGroupId: selectedSubGroup.subGroupId,
          subGroupName: selectedSubGroup.displayName,
          statusValue: selectedStatus,
          remarks: enteredRemarks,
          value: enteredValue,
          othersText: enteredOthers,
          attachmentUrl: enteredAttachmentPath,
          entryAt: BangladeshTime.isoLocal(),
        ));
        subGroups.removeWhere((e) => e.subGroupId == selectedSubGroup.subGroupId);
        if (subGroups.isEmpty) {
          groups.removeWhere((e) => e.groupId == selectedGroup.groupId);
          group = null;
        }
        setState(() {});
        if (mounted) _show('Checklist item saved locally. It will sync when internet is connected.');
      } else {
        await _reloadAfterInitiate();
        if (group != null && groups.any((e) => e.groupId == group!.groupId)) {
          await _loadSubGroups(group!);
        } else {
          group = null;
          subGroups = [];
        }
        if (mounted) _show('Checklist item saved');
      }
    } catch (e) {
      if (mounted) _show('Submit failed: $e', error: true);
    }
    if (mounted) setState(() => saving = false);
  }

  bool _isDenominationDetail(AuditChecklistDetailModel d) {
    return d.groupId == 2 && (d.subGroupId == 6 || d.subGroupName.toLowerCase().contains('denomination'));
  }

  Future<void> _editDenomination() async {
    if (master == null) return;
    await _openDenominationSheet();
  }

  Future<void> _editDetail(AuditChecklistDetailModel d) async {
    final oldGroup = AuditChecklistGroupModel(groupId: d.groupId, groupEnName: d.groupName, groupBnName: d.groupName);
    final oldSub = AuditChecklistSubGroupModel(subGroupId: d.subGroupId, groupId: d.groupId, subGroupEnName: d.subGroupName, subGroupBnName: d.subGroupName);
    final editRemarks = TextEditingController(text: d.remarks);
    final editValue = TextEditingController(text: d.value);
    String editStatus = d.statusValue.toUpperCase() == 'NO' ? 'No' : 'Yes';

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 20),
          decoration: const BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 48, height: 5, decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(99)))),
            const SizedBox(height: 16),
            const Text('Edit Checklist Item', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Text(d.subGroupName, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: editStatus,
              items: const [DropdownMenuItem(value: 'Yes', child: Text('Yes')), DropdownMenuItem(value: 'No', child: Text('No'))],
              onChanged: (v) => setModalState(() => editStatus = v ?? 'Yes'),
              decoration: const InputDecoration(labelText: 'Status', prefixIcon: Icon(Icons.rule_rounded)),
            ),
            const SizedBox(height: 12),
            TextField(controller: editValue, decoration: const InputDecoration(labelText: 'Value', prefixIcon: Icon(Icons.numbers_rounded))),
            const SizedBox(height: 12),
            TextField(controller: editRemarks, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Remarks', prefixIcon: Icon(Icons.notes_rounded))),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.save_rounded),
              label: const Text('Update'),
            ),
          ]),
        ),
      ),
    );

    if (ok != true) return;
    try {
      if (d.id < 0) {
        await AuditChecklistService.instance.updatePendingLocalDetail(
          masterId: d.masterId,
          subGroupId: d.subGroupId,
          statusValue: editStatus,
          remarks: editRemarks.text.trim(),
          value: editValue.text.trim(),
          othersText: d.othersText,
        );
        final index = details.indexWhere((e) => e.id == d.id);
        if (index >= 0) {
          details[index] = AuditChecklistDetailModel(
            id: d.id,
            masterId: d.masterId,
            groupId: d.groupId,
            groupName: d.groupName,
            subGroupId: d.subGroupId,
            subGroupName: d.subGroupName,
            statusValue: editStatus,
            remarks: editRemarks.text.trim(),
            value: editValue.text.trim(),
            othersText: d.othersText,
            attachmentUrl: d.attachmentUrl,
            entryAt: d.entryAt,
          );
        }
        setState(() {});
      } else {
        await AuditChecklistService.instance.saveDetail(
          masterId: master!.id,
          detailId: d.id,
          group: oldGroup,
          subGroup: oldSub,
          statusValue: editStatus,
          remarks: editRemarks.text.trim(),
          value: editValue.text.trim(),
          othersText: d.othersText,
        );
        await _reloadAfterInitiate();
      }
      _show('Checklist item updated');
    } catch (e) {
      _show('Update failed: $e', error: true);
    }
  }

  Future<void> _deleteDetail(AuditChecklistDetailModel d) async {
    if (_isDenominationDetail(d)) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Clear denomination?'),
          content: const Text('This will clear the denomination data for this checklist.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes, Clear')),
          ],
        ),
      );
      if (yes != true) return;
      try {
        await AuditChecklistService.instance.clearDenomination(d.masterId);
        details.removeWhere((e) => _isDenominationDetail(e));
        groups = await AuditChecklistService.instance.groups(d.masterId);
        setState(() {});
        _show('Denomination data cleared');
      } catch (e) {
        _show('Clear failed: $e', error: true);
      }
      return;
    }

    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text('Are you sure you want to delete "${d.subGroupName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes')),
        ],
      ),
    );
    if (yes != true) return;
    try {
      if (d.id < 0) {
        await AuditChecklistService.instance.deletePendingLocalDetail(masterId: d.masterId, subGroupId: d.subGroupId);
        details.removeWhere((e) => e.id == d.id);
        if (group?.groupId == d.groupId && !subGroups.any((e) => e.subGroupId == d.subGroupId)) {
          subGroups.add(AuditChecklistSubGroupModel(subGroupId: d.subGroupId, groupId: d.groupId, subGroupEnName: d.subGroupName, subGroupBnName: d.subGroupName));
          subGroups.sort((a, b) => a.subGroupId.compareTo(b.subGroupId));
        }
        if (!groups.any((e) => e.groupId == d.groupId)) {
          groups.add(AuditChecklistGroupModel(groupId: d.groupId, groupEnName: d.groupName, groupBnName: d.groupName));
          groups.sort((a, b) => a.groupId.compareTo(b.groupId));
        }
        setState(() {});
      } else {
        await AuditChecklistService.instance.deleteDetail(d.id);
        await _reloadAfterInitiate();
      }
      _show('Checklist item deleted');
    } catch (e) {
      _show('Delete failed: $e', error: true);
    }
  }

  Future<void> _cancel() async {
    if (master == null) {
      Navigator.pop(context, false);
      return;
    }
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel checklist?'),
        content: const Text('Draft checklist and added details will be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes, Cancel')),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await AuditChecklistService.instance.cancel(master!.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _show('Cancel failed: $e', error: true);
    }
  }

  Future<void> _confirm() async {
    if (master == null) return;
    if (details.isEmpty) {
      _show('Please add at least one checklist item.', error: true);
      return;
    }
    try {
      await AuditChecklistService.instance.confirm(master!.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _show('Confirm failed: $e', error: true);
    }
  }

  void _show(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.danger : AppColors.success,
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final initiated = master != null;
    return Scaffold(
      appBar: AppBar(title: Text(widget.existingMasterId == null ? 'Create Audit Checklist' : 'Add More Checklist')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _stepOne(initiated),
                if (initiated) ...[
                  const SizedBox(height: 14),
                  _stepTwo(),
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _stepThree(),
                    const SizedBox(height: 14),
                    _stepFour(),
                  ],
                ],
                const SizedBox(height: 30),
              ],
            ),
    );
  }

  Widget _stepOne(bool initiated) {
    return ProCard(
      color: const Color(0xFFEFF6FF),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionTitle(widget.existingMasterId == null ? 'Step 1 — Select Branch' : 'Existing Audit Session', subtitle: widget.existingMasterId == null ? 'Select branch and initiate today audit checklist' : 'Add more checklist items into this existing session'),
        if (widget.existingMasterId != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: Row(children: [
              const Icon(Icons.fact_check_rounded, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.existingBranchName?.trim().isEmpty == false ? widget.existingBranchName! : 'Checklist ID: ${widget.existingMasterId}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ]),
          )
        else ...[
          SearchableSelect<CompanyModel>(
            label: 'Branch',
            hint: 'Search branch',
            value: branch,
            items: branches,
            icon: Icons.business_rounded,
            titleBuilder: (b) => b.companyName,
            subtitleBuilder: (b) => 'Company ID: ${b.companyId}',
            onChanged: initiated ? (_) {} : (b) => setState(() => branch = b),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: initiated || initiating ? null : _initiate,
              icon: initiating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.play_circle_rounded),
              label: Text(initiated ? 'Initiated' : 'Initiate'),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _stepTwo() {
    return ProCard(
      color: const Color(0xFFF0FDFA),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionTitle('Step 2 — Add Checklist', subtitle: 'Completed sub groups disappear from the dropdown'),
        SearchableSelect<AuditChecklistGroupModel>(
          label: 'Checklist Group',
          hint: groups.isEmpty ? 'All groups completed' : 'Search checklist group',
          value: group,
          items: groups,
          icon: Icons.category_rounded,
          titleBuilder: (g) => g.displayName,
          subtitleBuilder: (g) => g.groupEnName,
          onChanged: _loadSubGroups,
        ),
        const SizedBox(height: 12),
        if (detailLoading)
          const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
        else
          SearchableSelect<AuditChecklistSubGroupModel>(
            label: 'Checklist Sub Group',
            hint: subGroups.isEmpty ? 'Select group first / all completed' : 'Search sub group',
            value: subGroup,
            items: subGroups,
            icon: Icons.checklist_rounded,
            titleBuilder: (s) => s.displayName,
            subtitleBuilder: (s) => s.subGroupEnName,
            onChanged: _selectSubGroup,
          ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: statusValue,
          items: const [DropdownMenuItem(value: 'Yes', child: Text('Yes')), DropdownMenuItem(value: 'No', child: Text('No'))],
          onChanged: (v) => setState(() => statusValue = v),
          decoration: const InputDecoration(labelText: 'Status', prefixIcon: Icon(Icons.rule_rounded)),
        ),
        const SizedBox(height: 12),
        TextField(controller: _remarks, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Remarks', prefixIcon: Icon(Icons.notes_rounded))),
        const SizedBox(height: 12),
        TextField(controller: _value, decoration: const InputDecoration(labelText: 'Value', prefixIcon: Icon(Icons.edit_note_rounded))),
        if (subGroup?.isOthers == true) ...[
          const SizedBox(height: 12),
          TextField(controller: _others, minLines: 2, maxLines: 3, decoration: const InputDecoration(labelText: 'Others Details / Specification *', prefixIcon: Icon(Icons.short_text_rounded))),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _chooseAttachment,
          icon: const Icon(Icons.attach_file_rounded),
          label: Text(_attachmentPath.isEmpty ? 'Add Attachment' : 'Change Attachment'),
        ),
        if (_attachmentPath.isNotEmpty) ...[
          const SizedBox(height: 10),
          ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.file(File(_attachmentPath), height: 140, width: double.infinity, fit: BoxFit.cover)),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: saving ? null : _submitDetail,
            icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_rounded),
            label: const Text('Submit'),
          ),
        ),
      ]),
    );
  }

  Widget _stepThree() {
    return ProCard(
      color: const Color(0xFFFFFBEB),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionTitle('Step 3 — Added Data', subtitle: '${details.length} checklist items added for selected branch'),
        if (details.isEmpty)
          const Text('No data added yet.', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700))
        else
          ...details.map((d) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d.subGroupName, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(d.groupName, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    _tag('Status: ${d.statusValue}', d.statusValue.toUpperCase() == 'YES' ? AppColors.success : AppColors.danger),
                    if (d.value.isNotEmpty) _tag('Value: ${d.value}', AppColors.secondary),
                    if (d.attachmentUrl.isNotEmpty) _tag('Attachment', AppColors.purple),
                  ]),
                  if (d.attachmentUrl.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _openAttachment(d),
                      icon: const Icon(Icons.visibility_rounded),
                      label: const Text('View Attachment'),
                    ),
                  ],
                  if (d.othersText.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Others: ${d.othersText}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  ],
                  if (d.remarks.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(d.remarks, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    if (_isDenominationDetail(d))
                      TextButton.icon(
                        onPressed: _editDenomination,
                        icon: const Icon(Icons.edit_note_rounded),
                        label: const Text('Edit Denomination'),
                      )
                    else
                      TextButton.icon(
                        onPressed: () => _editDetail(d),
                        icon: const Icon(Icons.edit_rounded),
                        label: const Text('Edit'),
                      ),
                    TextButton.icon(
                      onPressed: () => _deleteDetail(d),
                      icon: const Icon(Icons.delete_rounded, color: AppColors.danger),
                      label: Text(_isDenominationDetail(d) ? 'Clear' : 'Delete', style: const TextStyle(color: AppColors.danger)),
                    ),
                  ]),
                ]),
              )),
      ]),
    );
  }

  Widget _stepFour() {
    if (widget.existingMasterId != null) {
      return ProCard(
        color: const Color(0xFFFDF2F8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionTitle('Final Action', subtitle: 'Finish adding more checklist items'),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.done_all_rounded),
              label: const Text('Done'),
            ),
          ),
        ]),
      );
    }

    return ProCard(
      color: const Color(0xFFFDF2F8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionTitle('Step 4 — Final Action', subtitle: 'Cancel or confirm checklist for selected branch'),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: _cancel, icon: const Icon(Icons.close_rounded), label: const Text('Cancel'))),
          const SizedBox(width: 10),
          Expanded(child: FilledButton.icon(onPressed: _confirm, icon: const Icon(Icons.done_all_rounded), label: const Text('Confirm'))),
        ]),
      ]),
    );
  }

  Widget _tag(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withOpacity(.25))),
        child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11)),
      );
}


class _AuditAttachmentCropPage extends StatefulWidget {
  final String imagePath;
  const _AuditAttachmentCropPage({required this.imagePath});

  @override
  State<_AuditAttachmentCropPage> createState() => _AuditAttachmentCropPageState();
}

class _AuditAttachmentCropPageState extends State<_AuditAttachmentCropPage> {
  final GlobalKey _cropKey = GlobalKey();
  bool saving = false;

  Future<void> _confirmCrop() async {
    if (saving) return;
    setState(() => saving = true);
    try {
      final boundary = _cropKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        Navigator.pop(context, widget.imagePath);
        return;
      }
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List bytes = byteData!.buffer.asUint8List();
      final file = File('${Directory.systemTemp.path}/audit_attachment_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      Navigator.pop(context, file.path);
    } catch (_) {
      if (!mounted) return;
      Navigator.pop(context, widget.imagePath);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isLandscape = media.orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Crop Attachment'),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              final maxW = math.max(180.0, constraints.maxWidth - 24);
              final maxH = math.max(180.0, constraints.maxHeight - 24);
              final cropW = isLandscape ? math.min(maxW * .72, maxH * 1.6) : maxW;
              final cropH = isLandscape ? math.min(maxH, cropW * .62) : math.min(maxH, cropW * 1.05);

              return Center(
                child: Container(
                  width: cropW,
                  height: cropH,
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(.85), width: 2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: RepaintBoundary(
                    key: _cropKey,
                    child: InteractiveViewer(
                      minScale: .7,
                      maxScale: 5,
                      boundaryMargin: const EdgeInsets.all(120),
                      child: Image.file(File(widget.imagePath), fit: BoxFit.contain, width: cropW, height: cropH),
                    ),
                  ),
                ),
              );
            }),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(.22), blurRadius: 18, offset: const Offset(0, -6))],
            ),
            child: SafeArea(
              top: false,
              child: Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: saving ? null : () => Navigator.pop(context, widget.imagePath),
                    icon: const Icon(Icons.image_rounded),
                    label: const Text('Original'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: saving ? null : _confirmCrop,
                    icon: saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_rounded),
                    label: const Text('Confirm'),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
