import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/bangladesh_time.dart';

import '../core/app_theme.dart';
import '../models/collection_ledger_model.dart';
import '../models/outlet_model.dart';
import '../models/route_model.dart';
import '../services/collection_service.dart';
import '../services/master_data_service.dart';
import '../services/outlet_create_service.dart';
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

  List<OutletRouteModel> routes = [];
  List<OutletModel> outlets = [];
  OutletRouteModel? route;
  OutletModel? outlet;
  bool masterLoading = true;
  bool outletLoading = false;
  bool balanceLoading = false;
  double openingBalance = 0;

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
    collectionDate = df.format(BangladeshTime.now());
    amountCtrl.addListener(_amountChanged);
    _loadMaster();
  }

  @override
  void dispose() {
    amountCtrl.removeListener(_amountChanged);
    amountCtrl.dispose();
    remarksCtrl.dispose();
    super.dispose();
  }

  void _amountChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadMaster() async {
    if (mounted) setState(() => masterLoading = true);
    try {
      routes = await OutletCreateService.instance.routes();
    } catch (_) {
      routes = await MasterDataService.instance.routesFromOutlets();
    }
    if (routes.isEmpty) routes = await MasterDataService.instance.routesFromOutlets();
    if (mounted) setState(() => masterLoading = false);
  }

  Future<void> _selectRoute(OutletRouteModel selected) async {
    setState(() {
      route = selected;
      outlet = null;
      outlets = [];
      openingBalance = 0;
      outletLoading = true;
    });
    try {
      outlets = await OutletCreateService.instance.outletsByRoute(selected.routeId);
      if (outlets.isEmpty) outlets = await MasterDataService.instance.outlets(routeId: selected.routeId);
    } catch (_) {
      outlets = await MasterDataService.instance.outlets(routeId: selected.routeId);
    } finally {
      if (mounted) setState(() => outletLoading = false);
    }
  }

  Future<void> _selectOutlet(OutletModel selected) async {
    setState(() {
      outlet = selected;
      openingBalance = 0;
      balanceLoading = true;
    });
    try {
      openingBalance = await CollectionService.instance.outletCurrentBalance(selected.outletId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Outlet balance load failed: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => balanceLoading = false);
    }
  }

  Future<void> _loadLedgers(String selectedChannel) async {
    setState(() {
      channel = selectedChannel;
      ledger = null;
      ledgers = [];
      ledgerLoading = true;
    });
    try {
      final result = await CollectionService.instance.ledgerList(selectedChannel);
      if (!mounted) return;
      setState(() {
        ledgers = result;
        if (selectedChannel == 'Cash' && result.isNotEmpty) {
          ledger = result.first;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ledger load failed: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => ledgerLoading = false);
    }
  }

  void _clearEntrySelection() {
    amountCtrl.clear();
    remarksCtrl.clear();
    setState(() {
      route = null;
      outlet = null;
      outlets = [];
      openingBalance = 0;
      channel = null;
      ledger = null;
      ledgers = [];
    });
  }

  Future<void> _initiate() async {
    final id = await CollectionService.instance.createHeader(collectionDate: collectionDate);
    final col = await CollectionService.instance.getCollection(id);
    setState(() {
      collectionLocalId = id;
      collectionNo = '${col?['collection_no']}';
    });
  }

  Future<void> _addLine() async {
    final amount = double.tryParse(amountCtrl.text) ?? 0;
    if (collectionLocalId == null ||
        collectionNo == null ||
        route == null ||
        outlet == null ||
        amount <= 0 ||
        channel == null ||
        ledger == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select route, outlet, channel, ledger and enter valid amount')),
      );
      return;
    }

    final closingBalance = openingBalance + amount;
    await CollectionService.instance.addLine(
      collectionLocalId: collectionLocalId!,
      collectionNo: collectionNo!,
      route: route!,
      outlet: outlet!,
      openingBalance: openingBalance,
      closingBalance: closingBalance,
      amount: amount,
      channel: channel!,
      ledger: ledger!,
      remarks: remarksCtrl.text.trim(),
    );

    amountCtrl.clear();
    remarksCtrl.clear();
    setState(() {
      channel = null;
      ledger = null;
      ledgers = [];
    });
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
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _cancel() async {
    if (collectionLocalId != null) await CollectionService.instance.deleteCollection(collectionLocalId!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final initiated = collectionLocalId != null;
    final amount = double.tryParse(amountCtrl.text) ?? 0;
    final currentClosing = openingBalance + amount;
    final total = lines.fold<double>(0, (p, e) => p + (double.tryParse('${e['amount']}') ?? 0));

    return Scaffold(
      appBar: AppBar(title: const Text('Create Collection')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ProCard(
            color: const Color(0xFFF0F7FF),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Step 1 - Collection Header'),
                InkWell(
                  onTap: initiated
                      ? null
                      : () async {
                          final picked = await showDatePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: BangladeshTime.now(),
                            initialDate: DateTime.tryParse(collectionDate) ?? BangladeshTime.now(),
                          );
                          if (picked != null) setState(() => collectionDate = df.format(picked));
                        },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Collection Date', prefixIcon: Icon(Icons.calendar_month_rounded)),
                    child: Text(collectionDate, style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 12),
                if (!initiated)
                  FilledButton.icon(onPressed: _initiate, icon: const Icon(Icons.play_arrow_rounded), label: const Text('Initiate Collection'))
                else
                  Row(
                    children: [
                      Expanded(child: Text('Collection No: $collectionNo', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.secondary))),
                      const StatusChip('Draft'),
                    ],
                  ),
              ],
            ),
          ),
          if (initiated) ...[
            const SizedBox(height: 16),
            ProCard(
              color: const Color(0xFFF0FBF4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle('Step 2 - Add Outlet Collection'),
                  if (masterLoading)
                    const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                  else
                    SearchableSelect<OutletRouteModel>(
                      label: 'Route *',
                      hint: 'Search route by name/code',
                      value: route,
                      items: routes,
                      icon: Icons.alt_route_rounded,
                      titleBuilder: (item) => item.displayName,
                      subtitleBuilder: (item) => 'Route ID: ${item.routeId}',
                      onChanged: _selectRoute,
                    ),
                  const SizedBox(height: 12),
                  if (outletLoading)
                    const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                  else
                    IgnorePointer(
                      ignoring: route == null,
                      child: Opacity(
                        opacity: route == null ? .55 : 1,
                        child: OutletSearchField(
                          value: outlet,
                          outlets: outlets,
                          onChanged: _selectOutlet,
                          label: route == null ? 'Select Route First' : 'Outlet *',
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  _balanceBox(
                    'Opening Balance',
                    balanceLoading ? 'Loading...' : '৳ ${openingBalance.toStringAsFixed(2)}',
                    AppColors.secondary,
                  ),
                  const SizedBox(height: 12),
                  SearchableSelect<String>(
                    label: 'Collection Channel *',
                    hint: 'Select Cash, Bank, Cheque, MFS or POS',
                    value: channel,
                    items: CollectionService.channels,
                    icon: Icons.account_balance_wallet_rounded,
                    titleBuilder: (c) => c,
                    onChanged: _loadLedgers,
                  ),
                  const SizedBox(height: 12),
                  if (ledgerLoading)
                    const Center(child: Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator()))
                  else
                    SearchableSelect<CollectionLedgerModel>(
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
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Current Collection Amount', prefixIcon: Icon(Icons.payments_rounded)),
                  ),
                  const SizedBox(height: 12),
                  _balanceBox('Closing Balance', '৳ ${currentClosing.toStringAsFixed(2)}', AppColors.success),
                  const SizedBox(height: 4),
                  const Text(
                    'Opening Balance + Current Collection = Closing Balance',
                    style: TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: remarksCtrl, decoration: const InputDecoration(labelText: 'Remarks', prefixIcon: Icon(Icons.note_alt_rounded))),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _addLine,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add Collection'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: _clearEntrySelection,
                        icon: const Icon(Icons.clear_all_rounded),
                        label: const Text('Clear'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Route and outlet remain selected after adding a collection. Use Clear to reset them.',
                    style: TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ProCard(
              color: const Color(0xFFFFF7ED),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle('Step 3 - Review'),
                  if (lines.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('No collection line added yet.')),
                  ...lines.map((l) {
                    final lineOpening = double.tryParse('${l['opening_balance'] ?? 0}') ?? 0;
                    final lineAmount = double.tryParse('${l['amount'] ?? 0}') ?? 0;
                    final lineClosing = double.tryParse('${l['closing_balance'] ?? (lineOpening + lineAmount)}') ?? (lineOpening + lineAmount);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${l['outlet_name']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(
                        '${l['route_name'] ?? ''}\n${l['payment_type'] ?? l['collection_channel'] ?? 'Cash'} • ${l['ledger_name'] ?? ''}\nOpening ৳ ${lineOpening.toStringAsFixed(2)} + Collection ৳ ${lineAmount.toStringAsFixed(2)} = Closing ৳ ${lineClosing.toStringAsFixed(2)}\n${l['remarks'] ?? ''}',
                      ),
                      trailing: Text('৳ ${lineAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary)),
                    );
                  }),
                  const Divider(),
                  Row(
                    children: [
                      const Text('Total Collection', style: TextStyle(fontWeight: FontWeight.w900)),
                      const Spacer(),
                      Text('৳ ${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.primary)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ProCard(
              color: const Color(0xFFF8F5FF),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionTitle('Step 4 - Final Submission'),
                  FilledButton.icon(onPressed: _submit, icon: const Icon(Icons.check_circle_rounded), label: const Text('Confirm as UNCHECKED')),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(onPressed: _cancel, icon: const Icon(Icons.delete_forever_rounded), label: const Text('Cancel Collection')),
                ],
              ),
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _balanceBox(String label, String value, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(.22)),
      ),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
          const Spacer(),
          Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: color)),
        ],
      ),
    );
  }
}
