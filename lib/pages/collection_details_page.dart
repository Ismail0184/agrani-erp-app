import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../services/collection_service.dart';
import '../services/sync_service.dart';
import '../widgets/pro_widgets.dart';

class CollectionDetailsPage extends StatefulWidget {
  final String collectionLocalId;
  const CollectionDetailsPage({super.key, required this.collectionLocalId});

  @override
  State<CollectionDetailsPage> createState() => _CollectionDetailsPageState();
}

class _CollectionDetailsPageState extends State<CollectionDetailsPage> {
  Map<String, dynamic>? collection;
  List<Map<String, dynamic>> lines = [];
  bool loading = true;

  bool get isConfirmed => '${collection?['status']}' == 'CONFIRMED';
  bool get canModify => !isConfirmed;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    collection = await CollectionService.instance.getCollection(widget.collectionLocalId);
    lines = await CollectionService.instance.getLines(widget.collectionLocalId);
    if (mounted) setState(() => loading = false);
  }

  Future<void> _editLine(Map<String, dynamic> line) async {
    final amount = TextEditingController(text: '${line['amount']}');
    final remarks = TextEditingController(text: '${line['remarks'] ?? ''}');
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Collection'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${line['outlet_name']}', style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount')),
          const SizedBox(height: 10),
          TextField(controller: remarks, decoration: const InputDecoration(labelText: 'Remarks')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          FilledButton(onPressed: () async {
            await CollectionService.instance.updateLine(lineLocalId: '${line['local_id']}', amount: double.tryParse(amount.text) ?? 0, remarks: remarks.text.trim());
            await SyncService.instance.syncIfOnline();
            if (context.mounted) Navigator.pop(context);
          }, child: const Text('Update')),
        ],
      ),
    );
    _load();
  }

  Future<void> _deleteLine(Map<String, dynamic> line) async {
    final yes = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Delete Collection Line?'),
      content: Text('${line['outlet_name']} line will be removed.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes'))],
    ));
    if (yes == true) {
      await CollectionService.instance.deleteLine('${line['local_id']}');
      await SyncService.instance.syncIfOnline();
      _load();
    }
  }

  Future<void> _deleteCollection() async {
    final yes = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Delete Collection?'),
      content: Text('Collection ${collection?['collection_no']} will be deleted.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete'))],
    ));
    if (yes == true) {
      await CollectionService.instance.deleteCollection(widget.collectionLocalId);
      await SyncService.instance.syncIfOnline();
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _submit() async {
    if (lines.isEmpty) return;
    await CollectionService.instance.submitCollection(widget.collectionLocalId, finalConfirm: false);
    await SyncService.instance.syncIfOnline();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Collection submitted as UNCHECKED')));
    if (!widget.collectionLocalId.startsWith('server:')) {
      Navigator.pop(context);
      return;
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Collection Details')),
      body: loading ? const Center(child: CircularProgressIndicator()) : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ProCard(
            gradient: const LinearGradient(colors: [AppColors.primaryDark, AppColors.primary]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('${collection?['collection_no']}', style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900))),
                StatusChip('${collection?['status']}'),
              ]),
              const SizedBox(height: 10),
              Text('Date: ${collection?['collection_date']}  •  Total: ৳ ${double.tryParse('${collection?['total_amount'] ?? 0}')?.toStringAsFixed(2) ?? '0.00'}', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(height: 16),
          const SectionTitle('Outlet Collections'),
          ...lines.map((line) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ProCard(child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${line['outlet_name']}', style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('${line['payment_type'] ?? line['collection_channel'] ?? 'Cash'} • ${line['ledger_name'] ?? ''} • ${line['remarks'] ?? ''}', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('৳ ${(double.tryParse('${line['amount']}') ?? 0).toStringAsFixed(2)}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900)),
              ])),
              if (canModify) Column(children: [
                IconButton(onPressed: () => _editLine(line), icon: const Icon(Icons.edit_rounded, color: AppColors.secondary)),
                IconButton(onPressed: () => _deleteLine(line), icon: const Icon(Icons.delete_rounded, color: AppColors.danger)),
              ]),
            ])),
          )),
          if (canModify) ProCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            FilledButton.icon(onPressed: _submit, icon: const Icon(Icons.check_circle_rounded), label: const Text('Submit as UNCHECKED')),
            const SizedBox(height: 10),
            OutlinedButton.icon(onPressed: _deleteCollection, icon: const Icon(Icons.delete_forever_rounded), label: const Text('Delete Collection')),
          ])) else const ProCard(child: Text('This collection is CONFIRMED. Delete and update are disabled.', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w900))),
        ],
      ),
    );
  }
}
