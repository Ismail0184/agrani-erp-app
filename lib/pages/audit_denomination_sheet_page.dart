import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../services/audit_checklist_service.dart';
import '../widgets/pro_widgets.dart';

class AuditDenominationSheetPage extends StatefulWidget {
  final int masterId;
  const AuditDenominationSheetPage({super.key, required this.masterId});

  @override
  State<AuditDenominationSheetPage> createState() => _AuditDenominationSheetPageState();
}

class _AuditDenominationSheetPageState extends State<AuditDenominationSheetPage> {
  final denominations = const [1000, 500, 200, 100, 50, 20, 10, 5, 2, 1];
  final Map<String, TextEditingController> countCtrls = {};
  final othersAmount = TextEditingController(text: '0');
  bool saving = false;

  @override
  void initState() {
    super.initState();
    for (final d in denominations) {
      countCtrls['$d'] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final c in countCtrls.values) c.dispose();
    othersAmount.dispose();
    super.dispose();
  }

  double _count(int d) => double.tryParse(countCtrls['$d']?.text.trim() ?? '') ?? 0;
  double _amount(int d) => _count(d) * d;
  double get _others => double.tryParse(othersAmount.text.trim()) ?? 0;
  double get _total => denominations.fold<double>(0, (p, d) => p + _amount(d)) + _others;

  Future<void> _clearAll() async {
    final hasValue = _total > 0;
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear denomination?'),
        content: const Text('This will clear all denomination values from this screen and database.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes, Clear')),
        ],
      ),
    );
    if (yes != true) return;

    setState(() => saving = true);
    try {
      for (final c in countCtrls.values) {
        c.clear();
      }
      othersAmount.text = '0';
      await AuditChecklistService.instance.clearDenomination(widget.masterId);
      if (mounted) {
        setState(() {});
        _show(hasValue ? 'Denomination data cleared' : 'Denomination sheet cleared');
      }
    } catch (e) {
      if (mounted) _show('Clear failed: $e', error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _save() async {
    final items = <Map<String, dynamic>>[];
    for (final d in denominations) {
      final c = _count(d);
      if (c > 0) {
        items.add({'denomination_label': '$d', 'denomination_value': d, 'count': c, 'amount': c * d});
      }
    }
    if (_others > 0) {
      items.add({'denomination_label': 'Others', 'denomination_value': 0, 'count': 1, 'amount': _others});
    }
    if (items.isEmpty) {
      _show('Please enter at least one denomination value.', error: true);
      return;
    }
    setState(() => saving = true);
    try {
      final queued = await AuditChecklistService.instance.saveDenomination(masterId: widget.masterId, items: items);
      if (!mounted) return;
      _show(queued ? 'Denomination saved locally. It will sync when internet is connected.' : 'Denomination saved');
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) Navigator.pop(context, true);
      });
    } catch (e) {
      if (mounted) _show('Save failed: $e', error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
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
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('Denomination Sheet')),
      bottomNavigationBar: _bottomActions(),
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(builder: (context, constraints) {
          final compact = constraints.maxHeight < 620;
          return ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(14, 14, 14, compact ? 116 : 126),
            children: [
              ProCard(
                padding: EdgeInsets.all(compact ? 12 : 16),
                gradient: const LinearGradient(colors: [Color(0xFF2F8F2F), Color(0xFF76C943)]),
                child: Row(children: [
                  const Icon(Icons.payments_rounded, color: Colors.white, size: 32),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('Audit Denomination Sheet', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900))),
                  Text('৳ ${_total.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                ]),
              ),
              const SizedBox(height: 12),
              ProCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  Container(
                    decoration: const BoxDecoration(color: Color(0xFF6BBE38), borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
                    child: Row(children: const [
                      Expanded(child: _Head('Note')),
                      Expanded(child: _Head('Count')),
                      Expanded(child: _Head('Amount')),
                    ]),
                  ),
                  ...denominations.map((d) => _row(d, compact: compact)),
                  _othersRow(compact: compact),
                  Container(
                    padding: EdgeInsets.all(compact ? 12 : 14),
                    decoration: const BoxDecoration(color: Color(0xFFEFF6FF), borderRadius: BorderRadius.vertical(bottom: Radius.circular(22))),
                    child: Row(children: [
                      const Text('Grand Total', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      const Spacer(),
                      Text('৳ ${_total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.primary)),
                    ]),
                  ),
                ]),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _bottomActions() {
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(12, 10, 12, MediaQuery.of(context).viewInsets.bottom > 0 ? 10 : 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.08), blurRadius: 18, offset: const Offset(0, -8))],
        ),
        child: Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: saving ? null : () => Navigator.pop(context, false),
              icon: const Icon(Icons.close_rounded),
              label: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: saving ? null : _clearAll,
              icon: const Icon(Icons.cleaning_services_rounded),
              label: const Text('Clear'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: saving ? null : _save,
              icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_rounded),
              label: const Text('Confirm'),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _row(int d, {bool compact = false}) {
    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: compact ? 5 : 8),
      child: Row(children: [
        Expanded(child: Text('$d', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900))),
        Expanded(
          child: TextField(
            controller: countCtrls['$d'],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: compact ? 8 : 10)),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Expanded(child: Text(_amount(d).toStringAsFixed(2), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800))),
      ]),
    );
  }

  Widget _othersRow({bool compact = false}) {
    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))) ,
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: compact ? 5 : 8),
      child: Row(children: [
        const Expanded(child: Text('Others', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w900))),
        const Expanded(child: Text('-', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.muted))),
        Expanded(
          child: TextField(
            controller: othersAmount,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: compact ? 8 : 10)),
            onChanged: (_) => setState(() {}),
          ),
        ),
      ]),
    );
  }
}

class _Head extends StatelessWidget {
  final String text;
  const _Head(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
      );
}
