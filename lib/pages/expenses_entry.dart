import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/bangladesh_time.dart';

import '../core/app_theme.dart';
import '../models/ledger_model.dart';
import '../models/expense_vehicle_model.dart';
import '../services/expense_service.dart';
import '../widgets/pro_widgets.dart';
import 'app_drawer.dart';

class ExpensesEntryPage extends StatefulWidget {
  const ExpensesEntryPage({super.key});

  @override
  State<ExpensesEntryPage> createState() => _ExpensesEntryPageState();
}

class _ExpensesEntryPageState extends State<ExpensesEntryPage> {
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
      rows = await ExpenseService.instance.latestVouchers();
    } catch (e) {
      error = '$e';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _openCreate({String? voucherNo}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ExpenseVoucherCreatePage(voucherNo: voucherNo),
      ),
    );
    if (changed == true || voucherNo != null) await _load();
  }

  double _number(dynamic value) => double.tryParse('$value') ?? 0;

  bool _canModifyStatus(String status) {
    final value = status.trim().toUpperCase();
    return value == 'MANUAL' || value == 'DRAFT' || value == 'UNCHECKED';
  }

  Future<void> _deleteVoucher(String voucherNo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense Voucher'),
        content: Text(
          'Are you sure you want to delete voucher $voucherNo and all of its payment details?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ExpenseService.instance.cancelVoucher(voucherNo);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense voucher deleted successfully.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Expense Entry'),
        actions: [
          IconButton(
            onPressed: loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreate(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SectionTitle(
              'Latest Expense Vouchers',
              subtitle: 'The latest 10 app expense vouchers are shown here.',
            ),
            if (error != null)
              ProCard(
                color: AppColors.danger.withOpacity(.06),
                child: Text(
                  error!,
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            else if (loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(30),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (rows.isEmpty)
              const ProCard(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No expense voucher found.',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              )
            else
              ...rows.map(_voucherCard),
            const SizedBox(height: 90),
          ],
        ),
      ),
    );
  }

  Widget _voucherCard(Map<String, dynamic> row) {
    final voucherNo = '${row['voucher_no'] ?? ''}'.trim();
    final amount = _number(row['total_debit']);
    final status = '${row['status'] ?? 'MANUAL'}'.trim().toUpperCase();
    final canModify = voucherNo.isNotEmpty && _canModifyStatus(status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: canModify ? () => _openCreate(voucherNo: voucherNo) : null,
        borderRadius: BorderRadius.circular(22),
        child: ProCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      voucherNo,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                  StatusChip(status),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 16,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${row['voucher_date'] ?? '-'}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.phone_android_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'app',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const Divider(height: 22),
              Row(
                children: [
                  Expanded(
                    child: _amountSummary(
                      'Amount',
                      amount,
                      AppColors.secondary,
                    ),
                  ),
                  if (canModify) ...[
                    IconButton(
                      tooltip: 'Edit Voucher',
                      onPressed: () => _openCreate(voucherNo: voucherNo),
                      icon: const Icon(Icons.edit_rounded),
                      color: AppColors.primary,
                    ),
                    IconButton(
                      tooltip: 'Delete Voucher',
                      onPressed: () => _deleteVoucher(voucherNo),
                      icon: const Icon(Icons.delete_outline_rounded),
                      color: AppColors.danger,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _amountSummary(String label, double amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '৳ ${amount.toStringAsFixed(2)}',
          style: TextStyle(color: color, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class ExpenseVoucherCreatePage extends StatefulWidget {
  final String? voucherNo;

  const ExpenseVoucherCreatePage({super.key, this.voucherNo});

  @override
  State<ExpenseVoucherCreatePage> createState() =>
      _ExpenseVoucherCreatePageState();
}

class _ExpenseVoucherCreatePageState
    extends State<ExpenseVoucherCreatePage> {
  final DateFormat df = DateFormat('yyyy-MM-dd');
  final TextEditingController narrationCtrl = TextEditingController();
  final TextEditingController amountCtrl = TextEditingController();

  String voucherDate = '';
  String voucherNo = '';
  String status = 'MANUAL';
  static const Set<String> vehicleLedgerIds = {
    '4004000300000000',
    '4004000100000000',
    '4004001300000000',
    '4004000900000000',
    '4004000700000000',
    '4004000800000000',
    '4004000200000000',
    '4004001100000000',
    '4004001000000000',
    '4004000400000000',
    '4004000500000000',
    '4004000600000000',
    '4004001200000000',
  };

  List<LedgerModel> ledgers = [];
  List<ExpenseVehicleModel> vehicles = [];
  List<Map<String, dynamic>> lines = [];
  LedgerModel? ledger;
  ExpenseVehicleModel? vehicle;
  bool vehicleLoading = false;
  bool loading = true;
  bool initiated = false;
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    voucherDate = df.format(BangladeshTime.now());
    _loadInitial();
  }

  @override
  void dispose() {
    narrationCtrl.dispose();
    amountCtrl.dispose();
    super.dispose();
  }

  bool get editable {
    final value = status.toUpperCase();
    return initiated &&
        (value == 'MANUAL' || value == 'DRAFT' || value == 'UNCHECKED');
  }

  double _number(dynamic value) => double.tryParse('$value') ?? 0;

  double get totalAmount => lines.fold<double>(
        0,
        (sum, line) => sum + _number(line['dr_amt']),
      );

  bool get canConfirm => editable && totalAmount > 0;

  bool get vehicleRequired =>
      ledger != null && vehicleLedgerIds.contains(ledger!.ledgerId.trim());

  Future<void> _loadInitial() async {
    try {
      ledgers = await ExpenseService.instance.ledgers();
      if (widget.voucherNo != null && widget.voucherNo!.trim().isNotEmpty) {
        voucherNo = widget.voucherNo!.trim();
        final data = await ExpenseService.instance.voucherDetails(voucherNo);
        _applyVoucherData(data);
        initiated = true;
      } else {
        voucherNo = await ExpenseService.instance.nextVoucherNo();
      }
    } catch (e) {
      error = '$e';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _applyVoucherData(Map<String, dynamic> data) {
    final master = data['master'] is Map
        ? Map<String, dynamic>.from(data['master'] as Map)
        : <String, dynamic>{};
    voucherNo = '${master['voucher_no'] ?? voucherNo}'.trim();
    voucherDate = '${master['voucher_date'] ?? voucherDate}'.trim();
    status = '${master['status'] ?? 'MANUAL'}'.trim().toUpperCase();
    lines = (data['lines'] as List? ?? [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<void> _reloadDetails() async {
    if (voucherNo.isEmpty) return;
    final data = await ExpenseService.instance.voucherDetails(voucherNo);
    if (mounted) {
      setState(() {
        _applyVoucherData(data);
        initiated = true;
      });
    }
  }

  Future<void> _reloadLedgers() async {
    setState(() => busy = true);
    try {
      final result = await ExpenseService.instance.ledgers();
      if (!mounted) return;
      setState(() {
        ledgers = result;
        ledger = null;
        vehicle = null;
        vehicles = [];
      });
      if (result.isEmpty) {
        _show(
          'No expense ledger found for ledger group 4001 through 4009.',
          danger: true,
        );
      }
    } catch (e) {
      if (mounted) _show('$e', danger: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _selectLedger(LedgerModel selected) async {
    final needsVehicle = vehicleLedgerIds.contains(selected.ledgerId.trim());
    setState(() {
      ledger = selected;
      vehicle = null;
      if (!needsVehicle) vehicles = [];
      vehicleLoading = needsVehicle;
    });

    if (!needsVehicle) return;

    try {
      final result = await ExpenseService.instance.vehicles();
      if (!mounted || ledger?.ledgerId != selected.ledgerId) return;
      setState(() => vehicles = result);
      if (result.isEmpty) {
        _show('No vehicle found for the current company and section.', danger: true);
      }
    } catch (e) {
      if (mounted) _show('Vehicle list load failed: $e', danger: true);
    } finally {
      if (mounted && ledger?.ledgerId == selected.ledgerId) {
        setState(() => vehicleLoading = false);
      }
    }
  }

  Future<void> _pickDate() async {
    if (initiated || busy) return;
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: BangladeshTime.now(),
      initialDate: DateTime.tryParse(voucherDate) ?? BangladeshTime.now(),
    );
    if (picked != null) {
      setState(() => voucherDate = df.format(picked));
    }
  }

  Future<void> _initiate() async {
    if (voucherNo.isEmpty) {
      _show('Voucher number is not ready yet.', danger: true);
      return;
    }
    setState(() => busy = true);
    try {
      final data = await ExpenseService.instance.initiateVoucher(
        voucherNo: voucherNo,
        voucherDate: voucherDate,
      );
      if (!mounted) return;
      setState(() {
        _applyVoucherData(data);
        initiated = true;
      });
      _show('Expense voucher initiated successfully.');
    } catch (e) {
      if (mounted) _show('$e', danger: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _addLine() async {
    if (!editable) return;
    if (ledger == null) {
      _show('Please select a ledger.', danger: true);
      return;
    }

    if (vehicleRequired && vehicle == null) {
      _show('Please select a vehicle for the selected ledger.', danger: true);
      return;
    }

    final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) {
      _show('Please enter a valid amount greater than zero.', danger: true);
      return;
    }

    setState(() => busy = true);
    try {
      final data = await ExpenseService.instance.addLine(
        voucherNo: voucherNo,
        ledgerId: ledger!.ledgerId,
        narration: narrationCtrl.text.trim(),
        amount: amount,
        vehicleId: vehicle?.id ?? 0,
      );
      if (!mounted) return;
      setState(() {
        _applyVoucherData(data);
        ledger = null;
        vehicle = null;
        vehicles = [];
        narrationCtrl.clear();
        amountCtrl.clear();
      });
      _show('Payment detail added successfully.');
    } catch (e) {
      if (mounted) _show('$e', danger: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _deleteLine(Map<String, dynamic> line) async {
    if (!editable) return;
    final lineId = int.tryParse('${line['id'] ?? 0}') ?? 0;
    if (lineId <= 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Payment Detail'),
        content: const Text('Are you sure you want to remove this line?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => busy = true);
    try {
      final data = await ExpenseService.instance.deleteLine(
        voucherNo: voucherNo,
        lineId: lineId,
      );
      if (!mounted) return;
      setState(() => _applyVoucherData(data));
      _show('Payment detail removed.');
    } catch (e) {
      if (mounted) _show('$e', danger: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _confirmVoucher() async {
    if (!canConfirm) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Expense Voucher'),
        content: Text(
          'Voucher No: $voucherNo\n'
          'Total Amount: ৳ ${totalAmount.toStringAsFixed(2)}\n\n'
          'The voucher will be submitted as UNCHECKED. No data will be inserted into acc_transaction_journal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Voucher'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => busy = true);
    try {
      final data = await ExpenseService.instance.confirmVoucher(voucherNo);
      if (!mounted) return;
      setState(() => _applyVoucherData(data));
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Voucher Submitted'),
          content: Text(
            'Expense voucher $voucherNo has been submitted as UNCHECKED.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _show('$e', danger: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _cancelVoucher() async {
    if (!editable || voucherNo.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Expense Voucher'),
        content: Text(
          'Voucher $voucherNo and all added payment details will be deleted. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Cancel Voucher'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => busy = true);
    try {
      await ExpenseService.instance.cancelVoucher(voucherNo);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _show('$e', danger: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _show(String message, {bool danger = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: danger ? AppColors.danger : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(initiated ? 'Expense Voucher' : 'Create Expense'),
        actions: [
          if (initiated)
            IconButton(
              onPressed: busy ? null : _reloadDetails,
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (error != null) ...[
                  ProCard(
                    color: AppColors.danger.withOpacity(.06),
                    child: Text(
                      error!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                _voucherInformationCard(),
                if (initiated) ...[
                  const SizedBox(height: 16),
                  _paymentEntryCard(),
                  const SizedBox(height: 16),
                  _addedLinesCard(),
                ],
                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _voucherInformationCard() {
    return ProCard(
      color: const Color(0xFFF0F7FF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            '1. Voucher Information',
          ),
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Voucher No *',
              prefixIcon: Icon(Icons.confirmation_number_rounded),
            ),
            child: Text(
              voucherNo,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: initiated || busy ? null : _pickDate,
            borderRadius: BorderRadius.circular(16),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Transaction Date *',
                prefixIcon: Icon(Icons.calendar_month_rounded),
              ),
              child: Text(
                voucherDate,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (!initiated) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: busy || voucherNo.isEmpty ? null : _initiate,
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.play_arrow_rounded),
                label: Text(busy ? 'Initiating...' : 'Initiate Voucher'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _paymentEntryCard() {
    return ProCard(
      color: const Color(0xFFF0FBF4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            '2. Add Payment Details',
          ),
          if (!editable)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'This voucher is $status and cannot be modified.',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            )
          else ...[
            if (ledgers.isEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.danger.withOpacity(.25)),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'No ledger is currently available for ledger group 4001 through 4009.',
                        style: TextStyle(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Reload Ledgers',
                      onPressed: busy ? null : _reloadLedgers,
                      icon: const Icon(Icons.refresh_rounded),
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            SearchableSelect<LedgerModel>(
              label: 'Expense Ledger *',
              hint: ledgers.isEmpty
                  ? 'No ledger available'
                  : 'Search ledger by code or name',
              value: ledger,
              items: ledgers,
              icon: Icons.account_balance_rounded,
              titleBuilder: (item) => item.displayName,
              subtitleBuilder: (item) => item.ledgerId,
              onChanged: _selectLedger,
            ),
            if (vehicleRequired) ...[
              const SizedBox(height: 12),
              if (vehicleLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                SearchableSelect<ExpenseVehicleModel>(
                  label: 'Vehicle *',
                  hint: vehicles.isEmpty
                      ? 'No vehicle available'
                      : 'Search vehicle by registration or type',
                  value: vehicle,
                  items: vehicles,
                  icon: Icons.local_shipping_rounded,
                  titleBuilder: (item) => item.displayName,
                  subtitleBuilder: (item) => 'Vehicle ID: ${item.id}',
                  onChanged: (value) => setState(() => vehicle = value),
                ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: narrationCtrl,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Narration',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '৳ ',
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: busy || ledgers.isEmpty ? null : _addLine,
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.add_rounded),
                label: Text(busy ? 'Saving...' : 'Add Payment Detail'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _addedLinesCard() {
    return ProCard(
      color: const Color(0xFFFFF7ED),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            '3. Added Payment Details',
            subtitle: '${lines.length} line(s) added to voucher $voucherNo.',
          ),
          if (lines.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No payment detail added yet.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            )
          else
            ...lines.map(_lineCard),
          const Divider(height: 26),
          _totalRow('Total Amount', totalAmount, AppColors.secondary),
          if (editable) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : _cancelVoucher,
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancel Voucher'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy || !canConfirm ? null : _confirmVoucher,
                    icon: const Icon(Icons.check_circle_rounded),
                    label: const Text('Confirm Voucher'),
                  ),
                ),
              ],
            ),
            if (!canConfirm) ...[
              const SizedBox(height: 10),
              const Text(
                'Add at least one payment detail before confirming the voucher.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _lineCard(Map<String, dynamic> line) {
    final amount = _number(line['dr_amt']);
    final ledgerName = '${line['ledger_name'] ?? ''}'.trim();
    final ledgerId = '${line['ledger_id'] ?? ''}'.trim();
    final vehicleName = '${line['vehicle_name'] ?? ''}'.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ledgerName.isEmpty ? ledgerId : '$ledgerId - $ledgerName',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                if (vehicleName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Vehicle: $vehicleName',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                if ('${line['narration'] ?? ''}'.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${line['narration']}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  'Amount: ৳ ${amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          if (editable)
            IconButton(
              tooltip: 'Remove',
              onPressed: busy ? null : () => _deleteLine(line),
              icon: const Icon(Icons.delete_outline_rounded),
              color: AppColors.danger,
            ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, double amount, Color color) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
        Text(
          '৳ ${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 17,
            color: color,
          ),
        ),
      ],
    );
  }
}
