import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/app_theme.dart';
import '../models/outlet_model.dart';
import '../services/master_data_service.dart';
import '../services/order_service.dart';
import '../widgets/pro_widgets.dart';
import 'order_details_page.dart';

class ReportOrderListPage extends StatefulWidget {
  const ReportOrderListPage({super.key});

  @override
  State<ReportOrderListPage> createState() => _ReportOrderListPageState();
}

class _ReportOrderListPageState extends State<ReportOrderListPage> {
  final df = DateFormat('yyyy-MM-dd');
  late String from;
  late String to;
  OutletModel? outlet;
  List<OutletModel> outlets = [];
  List<Map<String, dynamic>> rows = [];
  bool loading = true;

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
    rows = await OrderService.instance.listOrders(from: from, to: to, outletId: outlet?.outletId, onlineOnly: true, includeLocalPending: false);
    if (mounted) setState(() => loading = false);
  }

  Future<void> _pickDate(bool isFrom) async {
    final current = DateTime.tryParse(isFrom ? from : to) ?? DateTime.now();
    final picked = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: current);
    if (picked == null) return;
    setState(() { if (isFrom) { from = df.format(picked); } else { to = df.format(picked); } });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report: Order List'), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))]),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ProCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SectionTitle('Filter Order Report', subtitle: 'Online database report with date and searchable outlet filter'),
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
            ])),
            const SizedBox(height: 16),
            SectionTitle('Online Order List', subtitle: '${rows.length} records found'),
            if (loading) const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()))
            else if (rows.isEmpty) const ProCard(child: Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No online order found'))))
            else ...rows.map(_card),
          ],
        ),
      ),
    );
  }

  Widget _dateBox(String label, String value, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: InputDecorator(decoration: InputDecoration(labelText: label, prefixIcon: const Icon(Icons.calendar_month_rounded)), child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800))),
  );

  Widget _card(Map<String, dynamic> row) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailsPage(orderLocalId: '${row['local_id']}'))),
      borderRadius: BorderRadius.circular(22),
      child: ProCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text('${row['order_no']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.secondary))), StatusChip('${row['status']}')]),
        const SizedBox(height: 8),
        Text('${row['outlet_name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Row(children: [
          Text('${row['order_date']}', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
          const Spacer(),
          Text('৳ ${double.tryParse('${row['total_amount'] ?? 0}')?.toStringAsFixed(2) ?? '0.00'}', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary)),
        ]),
      ])),
    ),
  );
}
