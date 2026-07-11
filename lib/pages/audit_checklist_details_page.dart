import 'dart:io';

import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../models/audit_checklist_models.dart';
import '../services/audit_checklist_service.dart';
import '../widgets/pro_widgets.dart';
import 'audit_checklist_create_page.dart';

class AuditChecklistDetailsPage extends StatefulWidget {
  final int masterId;
  final bool editable;
  const AuditChecklistDetailsPage({super.key, required this.masterId, required this.editable});

  @override
  State<AuditChecklistDetailsPage> createState() => _AuditChecklistDetailsPageState();
}

class _AuditChecklistDetailsPageState extends State<AuditChecklistDetailsPage> {
  List<AuditChecklistDetailModel> rows = [];
  bool loading = true;
  bool changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      rows = await AuditChecklistService.instance.details(widget.masterId);
    } catch (e) {
      if (mounted) _show('Details load failed: $e', error: true);
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _addMore() async {
    if (!widget.editable) return;
    final changedNow = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AuditChecklistCreatePage(
          existingMasterId: widget.masterId,
          existingBranchName: rows.isNotEmpty ? rows.first.groupName : '',
        ),
      ),
    );
    if (changedNow == true) {
      changed = true;
      await _load();
    }
  }

  Future<void> _delete(AuditChecklistDetailModel d) async {
    if (!widget.editable) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text('Delete "${d.subGroupName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes')),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await AuditChecklistService.instance.deleteDetail(d.id);
      changed = true;
      await _load();
      _show('Checklist item deleted');
    } catch (e) {
      _show('Delete failed: $e', error: true);
    }
  }

  bool _isDenomination(AuditChecklistDetailModel d) {
    return d.groupId == 2 || d.subGroupName.toLowerCase().contains('denomination');
  }

  Future<void> _clearDenomination() async {
    if (!widget.editable) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear denomination?'),
        content: const Text('This will clear all denomination data for this checklist.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes, Clear')),
        ],
      ),
    );
    if (yes != true) return;

    try {
      await AuditChecklistService.instance.clearDenomination(widget.masterId);
      changed = true;
      await _load();
      _show('Denomination data cleared');
    } catch (e) {
      _show('Clear failed: $e', error: true);
    }
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
                child: _attachmentImage(path),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _attachmentImage(String path) {
    final isNetwork = path.startsWith('http://') || path.startsWith('https://');
    if (isNetwork) {
      return Image.network(
        path,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) => progress == null ? child : const Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()),
        errorBuilder: (_, __, ___) => const Padding(padding: EdgeInsets.all(24), child: Text('Attachment image could not be loaded.')),
      );
    }

    final file = File(path);
    if (file.existsSync()) {
      return Image.file(file, fit: BoxFit.contain);
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Text(path, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
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
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, changed);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Audit Checklist Details'),
          actions: [
            if (widget.editable)
              TextButton.icon(
                onPressed: _addMore,
                icon: const Icon(Icons.add_circle_rounded, color: Colors.white),
                label: const Text('Add More', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
              ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ProCard(
                gradient: const LinearGradient(colors: [AppColors.primaryDark, AppColors.primary]),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Expanded(child: Text('Checklist Details', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900))),
                    if (widget.editable)
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primary),
                        onPressed: _addMore,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add More'),
                      ),
                  ]),
                  const SizedBox(height: 6),
                  Text(widget.editable ? 'Editable until CHECKED or APPROVED. Add more items into this session when needed.' : 'Read-only because this checklist is CHECKED or APPROVED.', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                ]),
              ),
              const SizedBox(height: 14),
              if (loading)
                const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()))
              else if (rows.isEmpty)
                const ProCard(child: Text('No details found.', style: TextStyle(fontWeight: FontWeight.w800)))
              else
                ...rows.map(_card),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(AuditChecklistDetailModel d) {
    final ok = d.statusValue.toUpperCase() == 'YES';
    final hasAttachment = d.attachmentUrl.trim().isNotEmpty;
    final isDenomination = _isDenomination(d);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ProCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 46, height: 46, decoration: BoxDecoration(color: (ok ? AppColors.success : AppColors.danger).withOpacity(.12), borderRadius: BorderRadius.circular(16)), child: Icon(ok ? Icons.check_circle_rounded : Icons.cancel_rounded, color: ok ? AppColors.success : AppColors.danger)),
            const SizedBox(width: 12),
            Expanded(child: Text(d.subGroupName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
          ]),
          const SizedBox(height: 8),
          Text(d.groupName, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            _tag('Status: ${d.statusValue}', ok ? AppColors.success : AppColors.danger),
            if (d.value.isNotEmpty) _tag('Value: ${d.value}', AppColors.secondary),
            if (hasAttachment) _tag('Attachment', AppColors.purple),
          ]),
          if (d.othersText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Others: ${d.othersText}', style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
          if (d.remarks.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(d.remarks, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
          if (hasAttachment || (widget.editable && (d.id > 0 || isDenomination))) ...[
            const Divider(height: 22),
            Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.end, children: [
              if (hasAttachment)
                OutlinedButton.icon(
                  onPressed: () => _openAttachment(d),
                  icon: const Icon(Icons.visibility_rounded),
                  label: const Text('View Attachment'),
                ),
              if (widget.editable && isDenomination)
                OutlinedButton.icon(
                  onPressed: _clearDenomination,
                  icon: const Icon(Icons.cleaning_services_rounded, color: AppColors.danger),
                  label: const Text('Clear Denomination', style: TextStyle(color: AppColors.danger)),
                ),
              if (widget.editable && d.id > 0 && !isDenomination)
                TextButton.icon(
                  onPressed: () => _delete(d),
                  icon: const Icon(Icons.delete_rounded, color: AppColors.danger),
                  label: const Text('Delete', style: TextStyle(color: AppColors.danger)),
                ),
            ]),
          ],
        ]),
      ),
    );
  }

  Widget _tag(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withOpacity(.25))),
        child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11)),
      );
}
