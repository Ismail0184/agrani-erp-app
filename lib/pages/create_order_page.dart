import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/app_theme.dart';
import '../models/item_model.dart';
import '../models/outlet_model.dart';
import '../models/route_model.dart';
import '../services/master_data_service.dart';
import '../services/order_service.dart';
import '../services/outlet_create_service.dart';
import '../services/sync_service.dart';
import '../widgets/pro_widgets.dart';

class CreateOrderPage extends StatefulWidget {
  const CreateOrderPage({super.key});

  @override
  State<CreateOrderPage> createState() => _CreateOrderPageState();
}

class _CreateOrderPageState extends State<CreateOrderPage> {
  final df = DateFormat('yyyy-MM-dd');
  late String orderDate;
  List<OutletRouteModel> routes = [];
  List<OutletModel> outlets = [];
  List<ItemModel> items = [];
  OutletRouteModel? route;
  OutletModel? outlet;
  ItemModel? item;
  String? orderLocalId;
  String? orderNo;
  double openingBalance = 0;
  bool masterLoading = true;
  bool outletLoading = false;
  bool initiating = false;
  final qtyCtrl = TextEditingController();
  final rateCtrl = TextEditingController();
  List<Map<String, dynamic>> lines = [];

  @override
  void initState() {
    super.initState();
    orderDate = df.format(DateTime.now());
    _loadMaster();
  }

  @override
  void dispose() {
    qtyCtrl.dispose();
    rateCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMaster() async {
    if (mounted) setState(() => masterLoading = true);
    items = await MasterDataService.instance.items();
    try {
      routes = await OutletCreateService.instance.routes();
    } catch (_) {
      routes = await MasterDataService.instance.routesFromOutlets();
    }
    if (routes.isEmpty) {
      routes = await MasterDataService.instance.routesFromOutlets();
    }
    if (mounted) setState(() => masterLoading = false);
  }

  Future<void> _selectRoute(OutletRouteModel selected) async {
    setState(() {
      route = selected;
      outlet = null;
      outlets = [];
      outletLoading = true;
    });
    try {
      outlets = await OutletCreateService.instance.outletsByRoute(selected.routeId);
      if (outlets.isEmpty) {
        outlets = await MasterDataService.instance.outlets(routeId: selected.routeId);
      }
    } catch (_) {
      outlets = await MasterDataService.instance.outlets(routeId: selected.routeId);
    } finally {
      if (mounted) setState(() => outletLoading = false);
    }
  }

  Future<void> _initiate() async {
    if (route == null) {
      _show('Please select route');
      return;
    }
    if (outlet == null) {
      _show('Please select outlet');
      return;
    }

    setState(() => initiating = true);
    try {
      double currentBalance = 0;
      try {
        currentBalance = await OrderService.instance.outletCurrentBalance(outlet!.outletId);
      } catch (e) {
        if (mounted) _show('Outlet balance load failed: $e');
      }

      final id = await OrderService.instance.createHeader(orderDate: orderDate, outlet: outlet!);
      final order = await OrderService.instance.getOrder(id);
      if (!mounted) return;
      setState(() {
        orderLocalId = id;
        orderNo = '${order?['order_no']}';
        openingBalance = currentBalance;
      });
    } finally {
      if (mounted) setState(() => initiating = false);
    }
  }

  Future<void> _addItem() async {
    final qty = double.tryParse(qtyCtrl.text) ?? 0;
    final rate = double.tryParse(rateCtrl.text) ?? 0;
    if (orderLocalId == null || orderNo == null || item == null || qty <= 0 || rate < 0) {
      _show('Please select item and enter valid qty/rate');
      return;
    }
    await OrderService.instance.addItem(orderLocalId: orderLocalId!, orderNo: orderNo!, item: item!, qty: qty, rate: rate);
    qtyCtrl.clear();
    rateCtrl.clear();
    item = null;
    await _loadLines();
  }

  Future<void> _loadLines() async {
    if (orderLocalId == null) return;
    lines = await OrderService.instance.getItems(orderLocalId!);
    if (mounted) setState(() {});
  }

  Future<void> _submit() async {
    if (orderLocalId == null || lines.isEmpty) {
      _show('Please add at least one item');
      return;
    }
    await OrderService.instance.submitOrder(orderLocalId!, finalConfirm: false);
    await SyncService.instance.syncIfOnline();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order submitted as UNCHECKED')));
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _cancel() async {
    if (orderLocalId != null) await OrderService.instance.deleteOrder(orderLocalId!);
    if (mounted) Navigator.pop(context);
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final initiated = orderLocalId != null;
    final total = lines.fold<double>(0, (p, e) => p + (double.tryParse('${e['amount']}') ?? 0));
    final closingBalance = total - openingBalance;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Order')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ProCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SectionTitle('Step 1 - Order Header'),
              InkWell(
                onTap: initiated
                    ? null
                    : () async {
                        final picked = await showDatePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                          initialDate: DateTime.tryParse(orderDate) ?? DateTime.now(),
                        );
                        if (picked != null) setState(() => orderDate = df.format(picked));
                      },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Order Date', prefixIcon: Icon(Icons.calendar_month_rounded)),
                  child: Text(orderDate, style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 12),
              if (masterLoading)
                const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
              else
                IgnorePointer(
                  ignoring: initiated,
                  child: SearchableSelect<OutletRouteModel>(
                    label: 'Route',
                    hint: 'Search route by name/code',
                    value: route,
                    items: routes,
                    icon: Icons.alt_route_rounded,
                    titleBuilder: (r) => r.displayName,
                    subtitleBuilder: (r) => 'Route ID: ${r.routeId}',
                    onChanged: _selectRoute,
                  ),
                ),
              const SizedBox(height: 12),
              if (outletLoading)
                const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
              else
                IgnorePointer(
                  ignoring: initiated || route == null,
                  child: Opacity(
                    opacity: route == null ? .55 : 1,
                    child: OutletSearchField(
                      value: outlet,
                      outlets: outlets,
                      onChanged: (o) => setState(() => outlet = o),
                      label: route == null ? 'Select Route First' : 'Outlet',
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              if (!initiated)
                FilledButton.icon(
                  onPressed: initiating ? null : _initiate,
                  icon: initiating
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.play_arrow_rounded),
                  label: Text(initiating ? 'Initiating...' : 'Initiate Order'),
                )
              else ...[
                Row(children: [
                  Expanded(child: Text('Order No: $orderNo', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.secondary))),
                  const StatusChip('Draft'),
                ]),
                const SizedBox(height: 12),
                _balanceRow('Outlet Current Balance', openingBalance, AppColors.secondary),
              ],
            ]),
          ),
          if (initiated) ...[
            const SizedBox(height: 16),
            ProCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SectionTitle('Step 2 - Add Items'),
                ItemSearchField(
                  value: item,
                  items: items,
                  onChanged: (i) => setState(() {
                    item = i;
                    rateCtrl.text = i.salesRate.toStringAsFixed(2);
                  }),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(controller: qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity', prefixIcon: Icon(Icons.numbers_rounded)))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: rateCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Rate', prefixIcon: Icon(Icons.price_change_rounded)))),
                ]),
                const SizedBox(height: 12),
                FilledButton.icon(onPressed: _addItem, icon: const Icon(Icons.add_rounded), label: const Text('Add Item')),
              ]),
            ),
            const SizedBox(height: 16),
            ProCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SectionTitle('Step 3 - Review Items'),
                if (lines.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('No item added yet.')),
                ...lines.map((l) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${l['item_name']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('Qty: ${l['qty']} × Rate: ${l['unit_price']}'),
                      trailing: Text('৳ ${(double.tryParse('${l['amount']}') ?? 0).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary)),
                    )),
                const Divider(),
                _balanceRow('Order Balance', total, AppColors.primary, large: true),
                const SizedBox(height: 8),
                _balanceRow('Opening Balance', openingBalance, AppColors.secondary),
                const Divider(),
                _balanceRow('Closing Balance', closingBalance, AppColors.success, large: true),
                const SizedBox(height: 4),
                const Text('Order Balance - Opening Balance = Closing Balance', style: TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w700)),
              ]),
            ),
            const SizedBox(height: 16),
            ProCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SectionTitle('Step 4 - Final Submission'),
                FilledButton.icon(onPressed: _submit, icon: const Icon(Icons.check_circle_rounded), label: const Text('Confirm as UNCHECKED')),
                const SizedBox(height: 10),
                OutlinedButton.icon(onPressed: _cancel, icon: const Icon(Icons.delete_forever_rounded), label: const Text('Cancel Order')),
              ]),
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _balanceRow(String label, double value, Color color, {bool large = false}) {
    return Row(children: [
      Text(label, style: TextStyle(fontWeight: FontWeight.w900, fontSize: large ? 16 : 14)),
      const Spacer(),
      Text('৳ ${value.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: large ? 18 : 15, color: color)),
    ]);
  }
}
