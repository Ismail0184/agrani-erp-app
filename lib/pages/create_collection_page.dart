import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/app_theme.dart';
import '../models/outlet_model.dart';
import '../models/collection_ledger_model.dart';
import '../services/collection_service.dart';
import '../services/master_data_service.dart';
import '../services/sync_service.dart';
import '../widgets/pro_widgets.dart';

class CreateCollectionPage extends StatefulWidget {
  const CreateCollectionPage({super.key});

  @override
  State<CreateCollectionPage> createState() => _CreateCollectionPageState();
}

class _CreateCollectionPageState extends State<CreateCollectionPage> {
  final df = DateFormat('yyyy-MM-dd');
  late String collectionDate;
  List<OutletModel> outlets = [];
  OutletModel? outlet;
  String? collectionLocalId;
  String? collectionNo;
  final amountCtrl = TextEditingController();
  final remarksCtrl = TextEditingController();
  List<Map<String, dynamic>> lines = [];

  String? channel;
  CollectionLedgerModel? ledger;
  List<CollectionLedgerModel> ledgers = [];
  bool ledgerLoading = false;

  @override
  void initState() {
    super.initState();
    collectionDate = df.format(DateTime.now());
    _loadMaster();
  }

  Future<void> _loadMaster() async {
    outlets = await MasterDataService.instance.outlets();
    if (mounted) setState(() {});
  }

  Future<void> _loadLedgers(String selectedChannel) async {
    setState(() {
      channel = selectedChannel;
      ledger = null;
      ledgers = [];
      ledgerLoading = true;
    });
    try {
      ledgers = await CollectionService.instance.ledgerList(selectedChannel);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ledger load failed: $e'), backgroundColor: AppColors.danger));
      }
    } finally {
      if (mounted) setState(() => ledgerLoading = false);
    }
  }

  Future<void> _initiate() async {
    final id = await CollectionService.instance.createHeader(collectionDate: collectionDate);
    final col = await CollectionService.instance.getCollection(id);
    setState(() { collectionLocalId = id; collectionNo = '${col?['collection_no']}'; });
  }

  Future<void> _addLine() async {
    final amount = double.tryParse(amountCtrl.text) ?? 0;
    if (collectionLocalId == null || collectionNo == null || outlet == null || amount <= 0 || channel == null || ledger == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select outlet, channel, ledger and enter valid amount')));
      return;
    }
    await CollectionService.instance.addLine(
      collectionLocalId: collectionLocalId!,
      collectionNo: collectionNo!,
      outlet: outlet!,
      amount: amount,
      channel: channel!,
      ledger: ledger!,
      remarks: remarksCtrl.text.trim(),
    );
    amountCtrl.clear();
    remarksCtrl.clear();
    outlet = null;
    channel = null;
    ledger = null;
    ledgers = [];
    await _loadLines();
  }

  Future<void> _loadLines() async {
    if (collectionLocalId == null) return;
    lines = await CollectionService.instance.getLines(collectionLocalId!);
    if (mounted) setState(() {});
  }

  Future<void> _submit() async {
    if (collectionLocalId == null || lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one collection line')));
      return;
    }
    await CollectionService.instance.submitCollection(collectionLocalId!, finalConfirm: false);
    await SyncService.instance.syncIfOnline();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Collection submitted as UNCHECKED')));
    Future.delayed(const Duration(milliseconds: 700), () { if (mounted) Navigator.pop(context); });
  }

  Future<void> _cancel() async {
    if (collectionLocalId != null) await CollectionService.instance.deleteCollection(collectionLocalId!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final initiated = collectionLocalId != null;
    final total = lines.fold<double>(0, (p, e) => p + (double.tryParse('${e['amount']}') ?? 0));
    return Scaffold(
      appBar: AppBar(title: const Text('Create Collection')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ProCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionTitle('Step 1 - Collection Header'),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Collection Date', prefixIcon: Icon(Icons.calendar_month_rounded)),
              child: Text(collectionDate, style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 12),
            if (!initiated) FilledButton.icon(onPressed: _initiate, icon: const Icon(Icons.play_arrow_rounded), label: const Text('Initiate Collection'))
            else Row(children: [Expanded(child: Text('Collection No: $collectionNo', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.secondary))), const StatusChip('Draft')]),
          ])),
          if (initiated) ...[
            const SizedBox(height: 16),
            ProCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SectionTitle('Step 2 - Add Outlet Collection'),
              OutletSearchField(value: outlet, outlets: outlets, onChanged: (o) => setState(() => outlet = o), label: 'Outlet'),
              const SizedBox(height: 12),
              SearchableSelect<String>(
                label: 'Collection Channel *',
                hint: 'Select Cash, Bank, MFS or POS',
                value: channel,
                items: CollectionService.channels,
                icon: Icons.account_balance_wallet_rounded,
                titleBuilder: (c) => c,
                onChanged: _loadLedgers,
              ),
              const SizedBox(height: 12),
              if (ledgerLoading) const Center(child: Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator()))
              else SearchableSelect<CollectionLedgerModel>(
                label: 'Ledger *',
                hint: channel == null ? 'Select channel first' : 'Search and select $channel ledger',
                value: ledger,
                items: ledgers,
                icon: Icons.account_balance_rounded,
                titleBuilder: (l) => l.displayName,
                subtitleBuilder: (l) => l.channel.isEmpty ? '' : l.channel,
                onChanged: (l) => setState(() => ledger = l),
              ),
              const SizedBox(height: 12),
              TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Collection Amount', prefixIcon: Icon(Icons.payments_rounded))),
              const SizedBox(height: 12),
              TextField(controller: remarksCtrl, decoration: const InputDecoration(labelText: 'Remarks', prefixIcon: Icon(Icons.note_alt_rounded))),
              const SizedBox(height: 12),
              FilledButton.icon(onPressed: _addLine, icon: const Icon(Icons.add_rounded), label: const Text('Add Collection')),
            ])),
            const SizedBox(height: 16),
            ProCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SectionTitle('Step 3 - Review'),
              if (lines.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('No collection line added yet.')),
              ...lines.map((l) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${l['outlet_name']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('${l['payment_type'] ?? l['collection_channel'] ?? 'Cash'} • ${l['ledger_name'] ?? ''}\n${l['remarks'] ?? ''}'),
                    trailing: Text('৳ ${(double.tryParse('${l['amount']}') ?? 0).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary)),
                  )),
              const Divider(),
              Row(children: [const Text('Total Collection', style: TextStyle(fontWeight: FontWeight.w900)), const Spacer(), Text('৳ ${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.primary))]),
            ])),
            const SizedBox(height: 16),
            ProCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SectionTitle('Step 4 - Final Submission'),
              FilledButton.icon(onPressed: _submit, icon: const Icon(Icons.check_circle_rounded), label: const Text('Confirm as UNCHECKED')),
              const SizedBox(height: 10),
              OutlinedButton.icon(onPressed: _cancel, icon: const Icon(Icons.delete_forever_rounded), label: const Text('Cancel Collection')),
            ])),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
