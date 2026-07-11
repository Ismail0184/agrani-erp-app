import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/app_theme.dart';
import '../models/outlet_model.dart';
import '../services/collection_service.dart';
import '../services/master_data_service.dart';
import '../widgets/pro_widgets.dart';
import 'app_drawer.dart';
import 'collection_details_page.dart';
import 'create_collection_page.dart';

class CollectionsPage extends StatefulWidget {
  const CollectionsPage({super.key});

  @override
  State<CollectionsPage> createState() => _CollectionsPageState();
}

class _CollectionsPageState extends State<CollectionsPage> {
  final df = DateFormat('yyyy-MM-dd');
  late String from;
  late String to;
  OutletModel? outlet;
  List<OutletModel> outlets = [];
  List<Map<String, dynamic>> rows = [];
  bool loading = true;
  bool showFilter = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    from = df.format(DateTime(now.year, now.month, 1));
    to = df.format(now);
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    outlets = await MasterDataService.instance.outlets();
    rows = await CollectionService.instance.listCollections(from: from, to: to, outletId: outlet?.outletId);
    if (mounted) setState(() => loading = false);
  }

  Future<void> _pickDate(bool isFrom) async {
    final current = DateTime.tryParse(isFrom ? from : to) ?? DateTime.now();
    final picked = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: current);
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        from = df.format(picked);
      } else {
        to = df.format(picked);
      }
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(title: const Text('Collection'), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateCollectionPage())); _load(); },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(children: [
              Expanded(child: SectionTitle('Collection List', subtitle: '${rows.length} records found')),
              IconButton.filledTonal(
                tooltip: showFilter ? 'Hide Filter' : 'Show Filter',
                onPressed: () => setState(() => showFilter = !showFilter),
                icon: Icon(showFilter ? Icons.filter_alt_off_rounded : Icons.filter_alt_rounded),
              ),
            ]),
            if (showFilter) ...[
              const SizedBox(height: 10),
              ProCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SectionTitle('Filter', subtitle: 'Date and searchable outlet filter'),
                  Row(children: [
                    Expanded(child: _dateBox('From Date', from, () => _pickDate(true))),
                    const SizedBox(width: 10),
                    Expanded(child: _dateBox('To Date', to, () => _pickDate(false))),
                  ]),
                  const SizedBox(height: 12),
                  OutletSearchField(value: outlet, outlets: outlets, onChanged: (o) { setState(() => outlet = o); _load(); }, label: 'Search Outlet'),
                  const SizedBox(height: 10),
                  Row(children: [
                    OutlinedButton.icon(onPressed: () { setState(() => outlet = null); _load(); }, icon: const Icon(Icons.clear_rounded), label: const Text('Clear Outlet')),
                    const Spacer(),
                    FilledButton.icon(onPressed: _load, icon: const Icon(Icons.filter_alt_rounded), label: const Text('Filter')),
                  ]),
                ]),
              ),
            ],
            const SizedBox(height: 16),
            if (loading) const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()))
            else if (rows.isEmpty) const ProCard(child: Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No collection found'))))
            else ...rows.map(_collectionCard),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _dateBox(String label, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, prefixIcon: const Icon(Icons.calendar_month_rounded)),
        child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }

  Widget _collectionCard(Map<String, dynamic> row) {
    final status = '${row['status']}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => CollectionDetailsPage(collectionLocalId: '${row['local_id']}'))); _load(); },
        borderRadius: BorderRadius.circular(22),
        child: ProCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('${row['collection_no']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.secondary))),
              StatusChip(status),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.muted),
              const SizedBox(width: 5),
              Text('${row['collection_date']}', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('৳ ${double.tryParse('${row['total_amount'] ?? 0}')?.toStringAsFixed(2) ?? '0.00'}', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary)),
            ]),
            if (status != 'CONFIRMED') const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Tap to view details, update or delete before confirmation.', style: TextStyle(color: AppColors.muted, fontSize: 12)),
            ),
          ]),
        ),
      ),
    );
  }
}
