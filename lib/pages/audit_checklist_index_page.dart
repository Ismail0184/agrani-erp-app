import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../models/audit_checklist_models.dart';
import '../models/company_model.dart';
import '../services/audit_checklist_service.dart';
import '../widgets/pro_widgets.dart';
import 'app_drawer.dart';
import 'audit_checklist_create_page.dart';
import 'audit_checklist_details_page.dart';
import '../core/bangladesh_time.dart';

class AuditChecklistIndexPage extends StatefulWidget {
  const AuditChecklistIndexPage({super.key});

  @override
  State<AuditChecklistIndexPage> createState() => _AuditChecklistIndexPageState();
}

class _AuditChecklistIndexPageState extends State<AuditChecklistIndexPage> {
  List<AuditChecklistMasterModel> rows = [];
  List<CompanyModel> branches = [];
  CompanyModel? filterBranch;
  DateTime? filterDate;
  bool loading = true;
  bool showFilter = false;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() => loading = true);
    try {
      branches = await AuditChecklistService.instance.branches();
      await _load();
    } catch (e) {
      if (mounted) _show('Audit checklist load failed: $e', error: true);
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _load() async {
    rows = await AuditChecklistService.instance.index(
      companyId: filterBranch?.companyId ?? 0,
      date: filterDate == null ? '' : _dateText(filterDate!),
    );
    if (mounted) setState(() {});
  }

  Future<void> _create() async {
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const AuditChecklistCreatePage()));
    if (ok == true && mounted) {
      await _load();
      _show('Audit checklist created successfully', seconds: 2);
    }
  }

  Future<void> _open(AuditChecklistMasterModel row) async {
    final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => AuditChecklistDetailsPage(masterId: row.id, editable: row.editable)));
    if (changed == true) await _load();
  }

  Future<void> _deleteChecklist(AuditChecklistMasterModel row) async {
    if (!row.editable) {
      _show('Checked or approved checklist cannot be deleted.', error: true);
      return;
    }
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete full checklist?'),
        content: Text('Are you sure you want to delete audit checklist of ${row.companyName.isEmpty ? 'Branch ID ${row.companyId}' : row.companyName} on ${row.date}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes, Delete')),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await AuditChecklistService.instance.cancel(row.id);
      await _loadInitial();
      _show('Checklist deleted successfully');
    } catch (e) {
      _show('Delete failed: $e', error: true);
    }
  }

  void _show(String message, {bool error = false, int seconds = 2}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.danger : AppColors.success,
      duration: Duration(seconds: seconds),
    ));
  }

  String _dateText(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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
      drawer: const AppDrawer(),
      appBar: AppBar(title: const Text('Audit Checklist'), actions: [IconButton(onPressed: _loadInitial, icon: const Icon(Icons.refresh_rounded))]),
      floatingActionButton: FloatingActionButton.extended(onPressed: _create, icon: const Icon(Icons.add_task_rounded), label: const Text('Create')),
      body: RefreshIndicator(
        onRefresh: _loadInitial,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ProCard(
              gradient: const LinearGradient(colors: [Color(0xFF0F172A), AppColors.primaryDark, AppColors.primary]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Audit Checklist', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                const Text('Latest 10 checklist sessions. Use the filter icon when branch/date search is needed.', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                Row(children: [
                  _pill('${rows.length} records'),
                  const SizedBox(width: 8),
                  _pill('Audit Department'),
                ]),
              ]),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: SectionTitle('Checklist List', subtitle: '${rows.length} records found')),
              IconButton.filledTonal(
                tooltip: showFilter ? 'Hide Filter' : 'Show Filter',
                onPressed: () => setState(() => showFilter = !showFilter),
                icon: Icon(showFilter ? Icons.filter_alt_off_rounded : Icons.filter_alt_rounded),
              ),
            ]),
            if (showFilter) ...[
              const SizedBox(height: 10),
              ProCard(
                color: const Color(0xFFF8FAFC),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SectionTitle('Filter', subtitle: 'Search by branch and date'),
                  SearchableSelect<CompanyModel>(
                    label: 'Branch',
                    hint: 'All branch',
                    value: filterBranch,
                    items: branches,
                    icon: Icons.business_rounded,
                    titleBuilder: (b) => b.companyName,
                    subtitleBuilder: (b) => 'ID: ${b.companyId}',
                    onChanged: (b) => setState(() => filterBranch = b),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(context: context, firstDate: DateTime(2024), lastDate: DateTime(2035), initialDate: filterDate ?? BangladeshTime.now());
                      if (picked != null) setState(() => filterDate = picked);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Date', prefixIcon: Icon(Icons.date_range_rounded)),
                      child: Text(filterDate == null ? 'All date' : _dateText(filterDate!), style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: OutlinedButton.icon(onPressed: () => setState(() { filterBranch = null; filterDate = null; _load(); }), icon: const Icon(Icons.clear_rounded), label: const Text('Clear'))),
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
              ProCard(
                child: Column(children: [
                  Container(width: 76, height: 76, decoration: BoxDecoration(color: AppColors.primary.withOpacity(.10), borderRadius: BorderRadius.circular(28)), child: const Icon(Icons.assignment_late_rounded, size: 40, color: AppColors.primary)),
                  const SizedBox(height: 12),
                  const Text('No checklist found', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                  const SizedBox(height: 6),
                  const Text('Click Create to start branch audit checklist.', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
                ]),
              )
            else
              ...rows.map(_card),
            const SizedBox(height: 86),
          ],
        ),
      ),
    );
  }

  Widget _pill(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(color: Colors.white.withOpacity(.16), borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
      );

  Widget _card(AuditChecklistMasterModel row) {
    final color = _statusColor(row.status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _open(row),
        borderRadius: BorderRadius.circular(22),
        child: ProCard(
          child: Row(children: [
            Container(width: 54, height: 54, decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(18)), child: Icon(Icons.fact_check_rounded, color: color)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(row.date, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(row.companyName.isEmpty ? 'Branch ID: ${row.companyId}' : row.companyName, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
                const SizedBox(height: 7),
                Row(children: [
                  _smallChip(row.status, color),
                  const SizedBox(width: 6),
                  _smallChip('${row.totalDetails} items', AppColors.secondary),
                ]),
              ]),
            ),
            if (row.editable) ...[
              IconButton(tooltip: 'Update', onPressed: () => _open(row), icon: const Icon(Icons.edit_rounded, color: AppColors.secondary)),
              IconButton(tooltip: 'Delete', onPressed: () => _deleteChecklist(row), icon: const Icon(Icons.delete_rounded, color: AppColors.danger)),
            ] else
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ]),
        ),
      ),
    );
  }

  Widget _smallChip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withOpacity(.25))),
        child: Text(text.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900)),
      );
}
