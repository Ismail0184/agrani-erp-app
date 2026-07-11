import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../models/audit_checklist_models.dart';
import '../models/company_model.dart';
import '../services/audit_checklist_service.dart';
import '../widgets/pro_widgets.dart';

class ReportAuditChecklistPage extends StatefulWidget {
  const ReportAuditChecklistPage({super.key});

  @override
  State<ReportAuditChecklistPage> createState() => _ReportAuditChecklistPageState();
}

class _ReportAuditChecklistPageState extends State<ReportAuditChecklistPage> {
  List<AuditChecklistMasterModel> rows = [];
  List<CompanyModel> branches = [];
  CompanyModel? branch;
  DateTime? date;
  bool loading = true;
  bool showFilter = false;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() => loading = true);
    branches = await AuditChecklistService.instance.branches();
    await _load();
    if (mounted) setState(() => loading = false);
  }

  String _dateText(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    rows = await AuditChecklistService.instance.index(
      companyId: branch?.companyId ?? 0,
      date: date == null ? '' : _dateText(date!),
    );
    if (mounted) setState(() {});
  }

  Color _statusColor(String status) {
    final s = status.toUpperCase();
    if (s == 'APPROVED') return AppColors.success;
    if (s == 'CHECKED') return AppColors.secondary;
    if (s == 'UNCHECKED') return AppColors.accent;
    return AppColors.purple;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audit Checklist Report'), actions: [IconButton(onPressed: _loadInitial, icon: const Icon(Icons.refresh_rounded))]),
      body: RefreshIndicator(
        onRefresh: _loadInitial,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(children: [
              Expanded(child: SectionTitle('Audit Checklist Data', subtitle: '${rows.length} records found')),
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
                  const SectionTitle('Filter', subtitle: 'Branch and date-wise online audit report'),
                  SearchableSelect<CompanyModel>(
                    label: 'Branch',
                    hint: 'All branch',
                    value: branch,
                    items: branches,
                    icon: Icons.business_rounded,
                    titleBuilder: (b) => b.companyName,
                    subtitleBuilder: (b) => 'ID: ${b.companyId}',
                    onChanged: (b) => setState(() => branch = b),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(context: context, firstDate: DateTime(2024), lastDate: DateTime(2035), initialDate: date ?? DateTime.now());
                      if (picked != null) setState(() => date = picked);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Date', prefixIcon: Icon(Icons.date_range_rounded)),
                      child: Text(date == null ? 'All date' : _dateText(date!), style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: OutlinedButton.icon(onPressed: () { setState(() { branch = null; date = null; }); _load(); }, icon: const Icon(Icons.clear_rounded), label: const Text('Clear'))),
                    const SizedBox(width: 10),
                    Expanded(child: FilledButton.icon(onPressed: _load, icon: const Icon(Icons.search_rounded), label: const Text('Search'))),
                  ]),
                ]),
              ),
            ],
            const SizedBox(height: 14),
            if (loading)
              const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()))
            else if (rows.isEmpty)
              const ProCard(child: Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No audit checklist found'))))
            else
              ...rows.map(_card),
          ],
        ),
      ),
    );
  }

  Widget _card(AuditChecklistMasterModel row) {
    final color = _statusColor(row.status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ProCard(
        child: Row(children: [
          Container(width: 52, height: 52, decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(18)), child: Icon(Icons.fact_check_rounded, color: color)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(row.date, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(row.companyName.isEmpty ? 'Branch ID: ${row.companyId}' : row.companyName, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
            const SizedBox(height: 7),
            Row(children: [
              _chip(row.status, color),
              const SizedBox(width: 6),
              _chip('${row.totalDetails} items', AppColors.secondary),
            ]),
          ])),
        ]),
      ),
    );
  }

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withOpacity(.25))),
        child: Text(text.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900)),
      );
}
