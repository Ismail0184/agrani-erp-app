import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../widgets/pro_widgets.dart';
import 'app_drawer.dart';
import 'report_collection_list_page.dart';
import 'report_gps_track_page.dart';
import 'report_order_list_page.dart';
import 'report_audit_checklist_page.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ProCard(
            gradient: const LinearGradient(colors: [AppColors.primaryDark, AppColors.primary, AppColors.secondary]),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ERP Online Reports', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
              SizedBox(height: 6),
              Text('All report data loads from the online database through API.', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(height: 16),
          _reportTile(context, Icons.shopping_bag_rounded, 'Order List', 'Date and outlet-wise online order report', const ReportOrderListPage(), AppColors.secondary),
          _reportTile(context, Icons.payments_rounded, 'Collection List', 'Date and outlet-wise online collection report', const ReportCollectionListPage(), AppColors.success),
          _reportTile(context, Icons.location_on_rounded, 'GPS Track', 'Date-wise online GPS movement history', const ReportGpsTrackPage(), AppColors.danger),
          _reportTile(context, Icons.fact_check_rounded, 'Audit Checklist', 'Branch and date-wise online audit checklist report', const ReportAuditChecklistPage(), AppColors.purple),
        ],
      ),
    );
  }

  Widget _reportTile(BuildContext context, IconData icon, String title, String subtitle, Widget page, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
        borderRadius: BorderRadius.circular(22),
        child: ProCard(
          child: Row(children: [
            Container(width: 52, height: 52, decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(18)), child: Icon(icon, color: color)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.text)),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w700)),
            ])),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ]),
        ),
      ),
    );
  }
}
