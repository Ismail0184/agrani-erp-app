import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../services/delivery_service.dart';
import '../widgets/pro_widgets.dart';
import 'app_drawer.dart';

class OrderPendingDeliveryPage extends StatefulWidget {
  const OrderPendingDeliveryPage({super.key});

  @override
  State<OrderPendingDeliveryPage> createState() => _OrderPendingDeliveryPageState();
}

class _OrderPendingDeliveryPageState extends State<OrderPendingDeliveryPage> {
  List<Map<String, dynamic>> rows = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      rows = await DeliveryService.instance.pendingOrders();
    } catch (e) {
      error = '$e';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _open(Map<String, dynamic> order) async {
    final orderNo = '${order['order_no'] ?? ''}'.trim();
    if (orderNo.isEmpty) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => OrderDeliveryPage(orderNo: orderNo),
      ),
    );
    if (changed == true) await _load();
  }

  double _number(dynamic value) => double.tryParse('$value') ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Pending Delivery'),
        actions: [
          IconButton(
            onPressed: loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: loading
            ? ListView(
          children: [
            SizedBox(height: 240),
            Center(child: CircularProgressIndicator()),
          ],
        )
            : ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ProCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle(
                    'Assigned Pending Orders',
                    subtitle: 'Only orders assigned to the logged-in user are shown.',
                  ),
                  if (error != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withOpacity(.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.danger.withOpacity(.25)),
                      ),
                      child: Text(
                        error!,
                        style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700),
                      ),
                    )
                  else if (rows.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.local_shipping_outlined, size: 48, color: AppColors.muted),
                            SizedBox(height: 10),
                            Text('No pending delivery order found.', style: TextStyle(fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    )
                  else
                    ...rows.map((row) {
                      final orderQty = _number(row['order_qty'] ?? row['total_qty']);
                      final deliveredQty = _number(row['delivered_qty']);
                      final pendingQty = _number(row['pending_qty']);
                      final status = '${row['delivery_status'] ?? 'PENDING'}';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () => _open(row),
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Order: ${row['order_no'] ?? ''}',
                                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                                      ),
                                    ),
                                    StatusChip(status),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${row['outlet_name'] ?? 'Outlet'}',
                                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.secondary),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Order Date: ${row['order_date'] ?? '-'}',
                                  style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600),
                                ),
                                const Divider(height: 22),
                                Row(
                                  children: [
                                    Expanded(child: _qtyText('Ordered', orderQty)),
                                    Expanded(child: _qtyText('Delivered', deliveredQty)),
                                    Expanded(child: _qtyText('Pending', pendingQty, color: AppColors.danger)),
                                    const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _qtyText(String label, double value, {Color color = AppColors.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(_qty(value), style: TextStyle(fontWeight: FontWeight.w900, color: color)),
      ],
    );
  }

  String _qty(double value) => value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(3);
}

class OrderDeliveryPage extends StatefulWidget {
  final String orderNo;
  const OrderDeliveryPage({super.key, required this.orderNo});

  @override
  State<OrderDeliveryPage> createState() => _OrderDeliveryPageState();
}

class _OrderDeliveryPageState extends State<OrderDeliveryPage> {
  Map<String, dynamic> order = {};
  List<Map<String, dynamic>> items = [];
  final Map<int, TextEditingController> controllers = {};
  bool loading = true;
  bool confirming = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  double _number(dynamic value) => double.tryParse('$value') ?? 0;

  String _qty(double value) => value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(3);

  Future<void> _load() async {
    try {
      final data = await DeliveryService.instance.orderDetails(widget.orderNo);
      order = Map<String, dynamic>.from(data['order'] as Map);
      items = (data['items'] as List).map((row) => Map<String, dynamic>.from(row as Map)).toList();
      for (final old in controllers.values) {
        old.dispose();
      }
      controllers.clear();
      for (final item in items) {
        final id = int.tryParse('${item['id'] ?? item['order_detail_id'] ?? 0}') ?? 0;
        final pending = _number(item['pending_qty'] ?? item['qty']);
        controllers[id] = TextEditingController(text: _qty(pending));
      }
    } catch (e) {
      error = '$e';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _confirm() async {
    final payload = <Map<String, dynamic>>[];
    bool mismatch = false;

    for (final item in items) {
      final id = int.tryParse('${item['id'] ?? item['order_detail_id'] ?? 0}') ?? 0;
      final pending = _number(item['pending_qty'] ?? item['qty']);
      final deliveryQty = double.tryParse(controllers[id]?.text.trim() ?? '') ?? -1;
      if (deliveryQty < 0) {
        _show('Delivery quantity cannot be negative.');
        return;
      }
      if (deliveryQty > pending + 0.000001) {
        _show('Delivery quantity cannot exceed order quantity for ${item['item_name'] ?? 'item'}.');
        return;
      }
      if ((pending - deliveryQty).abs() > 0.000001) mismatch = true;
      payload.add({
        'order_detail_id': id,
        'delivery_qty': deliveryQty,
      });
    }

    bool closeOrder = true;
    if (mismatch) {
      final decision = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Partial Delivery Confirmation'),
          content: const Text(
            'Order quantity and delivery quantity do not match. Do you want to close this order now, or keep it open for future delivery?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(ctx, false),
              icon: const Icon(Icons.schedule_rounded),
              label: const Text('Keep Open'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.lock_rounded),
              label: const Text('Close Order'),
            ),
          ],
        ),
      );
      if (decision == null) return;
      closeOrder = decision;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirm Full Delivery'),
          content: const Text('All ordered quantities will be delivered and the order will be fully confirmed.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm Delivery')),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => confirming = true);
    try {
      final result = await DeliveryService.instance.confirmDelivery(
        orderNo: widget.orderNo,
        closeOrder: closeOrder,
        items: payload,
      );
      if (!mounted) return;
      final message = '${result['message'] ?? 'Delivery confirmed successfully.'}';
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delivery Confirmed'),
          content: Text(message),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _show('$e');
    } finally {
      if (mounted) setState(() => confirming = false);
    }
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.danger),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalPending = items.fold<double>(0, (sum, item) => sum + _number(item['pending_qty'] ?? item['qty']));
    final totalDelivery = items.fold<double>(0, (sum, item) {
      final id = int.tryParse('${item['id'] ?? item['order_detail_id'] ?? 0}') ?? 0;
      return sum + (double.tryParse(controllers[id]?.text.trim() ?? '') ?? 0);
    });

    return Scaffold(
      appBar: AppBar(title: Text('Delivery - ${widget.orderNo}')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(error!, textAlign: TextAlign.center)))
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ProCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Order Information'),
                _info('Order No', '${order['order_no'] ?? widget.orderNo}'),
                _info('Order Date', '${order['order_date'] ?? '-'}'),
                _info('Outlet', '${order['outlet_name'] ?? '-'}'),
                _info('Status', 'PENDING DELIVERY'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ProCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle(
                  'Delivery Items',
                  subtitle: 'Delivery quantity may be zero, but it cannot exceed order quantity.',
                ),
                if (items.isEmpty)
                  const Padding(padding: EdgeInsets.all(12), child: Text('No pending item found.'))
                else
                  ...items.map((item) {
                    final id = int.tryParse('${item['id'] ?? item['order_detail_id'] ?? 0}') ?? 0;
                    final original = _number(item['order_qty'] ?? item['qty']);
                    final delivered = _number(item['delivered_qty']);
                    final pending = _number(item['pending_qty'] ?? item['qty']);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${item['item_name'] ?? 'Item'}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                          const SizedBox(height: 4),
                          Text(
                            'Original Qty: ${_qty(original)} • Previously Delivered: ${_qty(delivered)}',
                            style: const TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextFormField(
                                  readOnly: true,
                                  initialValue: _qty(pending),
                                  decoration: const InputDecoration(labelText: 'Order Qty'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: controllers[id],
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(labelText: 'Delivery Qty'),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ProCard(
            child: Column(
              children: [
                _summary('Pending Order Qty', totalPending, AppColors.secondary),
                const SizedBox(height: 8),
                _summary('Current Delivery Qty', totalDelivery, AppColors.primary),
                const Divider(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: confirming || items.isEmpty ? null : _confirm,
                    icon: confirming
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.local_shipping_rounded),
                    label: Text(confirming ? 'Confirming...' : 'Confirm Delivery'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 105, child: Text(label, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w900))),
        ],
      ),
    );
  }

  Widget _summary(String label, double value, Color color) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900))),
        Text(_qty(value), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: color)),
      ],
    );
  }
}
