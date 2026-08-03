import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../services/order_service.dart';
import '../services/sync_service.dart';
import '../widgets/pro_widgets.dart';

class OrderDetailsPage extends StatefulWidget {
  final String orderLocalId;
  final bool confirmationMode;
  const OrderDetailsPage({super.key, required this.orderLocalId, this.confirmationMode = false});

  @override
  State<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> {
  Map<String, dynamic>? order;
  List<Map<String, dynamic>> lines = [];
  bool loading = true;

  String get orderStatus => '${order?['status'] ?? ''}'.trim().toUpperCase();
  bool get canModify => orderStatus == 'UNCHECKED';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    order = await OrderService.instance.getOrder(widget.orderLocalId);
    lines = await OrderService.instance.getItems(widget.orderLocalId);
    if (mounted) setState(() => loading = false);
  }

  Future<void> _editLine(Map<String, dynamic> line) async {
    final qty = TextEditingController(text: '${line['qty']}');
    final rate = TextEditingController(text: '${line['unit_price']}');
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Item Qty & Rate'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${line['item_name']}', style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          TextField(controller: qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity')),
          const SizedBox(height: 10),
          TextField(controller: rate, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Rate')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          FilledButton(onPressed: () async {
            await OrderService.instance.updateLine(lineLocalId: '${line['local_id']}', qty: double.tryParse(qty.text) ?? 0, rate: double.tryParse(rate.text) ?? 0);
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
      title: const Text('Delete Item?'),
      content: Text('${line['item_name']} will be removed from order.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes'))],
    ));
    if (yes == true) {
      await OrderService.instance.deleteLine('${line['local_id']}');
      await SyncService.instance.syncIfOnline();
      _load();
    }
  }

  Future<void> _deleteOrder() async {
    final yes = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Delete Order?'),
      content: Text('Order ${order?['order_no']} will be deleted.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete'))],
    ));
    if (yes == true) {
      await OrderService.instance.deleteOrder(widget.orderLocalId);
      await SyncService.instance.syncIfOnline();
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _confirmFinal() async {
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No item found')));
      return;
    }
    await OrderService.instance.submitOrder(widget.orderLocalId, finalConfirm: true);
    await SyncService.instance.syncIfOnline();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order CONFIRMED. Now it is read-only.')));
    if (!widget.orderLocalId.startsWith('server:')) {
      Navigator.pop(context);
      return;
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Order Details')),
      body: loading ? const Center(child: CircularProgressIndicator()) : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ProCard(
            gradient: const LinearGradient(colors: [AppColors.primaryDark, AppColors.primary]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('${order?['order_no']}', style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900))),
                StatusChip('${order?['status']}'),
              ]),
              const SizedBox(height: 10),
              Text('${order?['outlet_name']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('Date: ${order?['order_date']}  •  Total: ৳ ${double.tryParse('${order?['total_amount'] ?? 0}')?.toStringAsFixed(2) ?? '0.00'}', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(height: 16),
          const SectionTitle('Items', subtitle: 'Tap edit before final confirmation'),
          ...lines.map((line) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ProCard(
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${line['item_name']}', style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text('Qty: ${line['qty']} × Rate: ${line['unit_price']}', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('৳ ${(double.tryParse('${line['amount']}') ?? 0).toStringAsFixed(2)}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900)),
                ])),
                if (canModify) Column(children: [
                  IconButton(onPressed: () => _editLine(line), icon: const Icon(Icons.edit_rounded, color: AppColors.secondary)),
                  IconButton(onPressed: () => _deleteLine(line), icon: const Icon(Icons.delete_rounded, color: AppColors.danger)),
                ]),
              ]),
            ),
          )),
          if (lines.isEmpty) const ProCard(child: Padding(padding: EdgeInsets.all(18), child: Text('No item found'))),
          const SizedBox(height: 16),
          if (canModify) ProCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (widget.confirmationMode) FilledButton.icon(onPressed: _confirmFinal, icon: const Icon(Icons.verified_rounded), label: const Text('Final Confirm Order'))
              else FilledButton.icon(onPressed: () async { await OrderService.instance.submitOrder(widget.orderLocalId); await SyncService.instance.syncIfOnline(); if (mounted) Navigator.pop(context); }, icon: const Icon(Icons.check_circle_rounded), label: const Text('Submit as UNCHECKED')),
              const SizedBox(height: 10),
              OutlinedButton.icon(onPressed: _deleteOrder, icon: const Icon(Icons.delete_forever_rounded), label: const Text('Delete Order')),
            ]),
          ) else const ProCard(child: Text('Only UNCHECKED orders can be edited or deleted. This order is read-only.', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w900))),
        ],
      ),
    );
  }
}
