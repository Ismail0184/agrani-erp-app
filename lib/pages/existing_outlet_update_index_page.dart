import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../models/outlet_master_model.dart';
import '../services/outlet_create_service.dart';
import '../widgets/pro_widgets.dart';
import 'app_drawer.dart';
import 'existing_outlet_update_page.dart';

class ExistingOutletUpdateIndexPage extends StatefulWidget {
  const ExistingOutletUpdateIndexPage({super.key});

  @override
  State<ExistingOutletUpdateIndexPage> createState() => _ExistingOutletUpdateIndexPageState();
}

class _ExistingOutletUpdateIndexPageState extends State<ExistingOutletUpdateIndexPage> {
  List<OutletMasterModel> rows = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => loading = true);
    try {
      rows = await OutletCreateService.instance.existingOutletUpdateList();
    } catch (e) {
      if (mounted) _show('Outlet list load failed: $e', error: true);
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _open(OutletMasterModel outlet) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ExistingOutletUpdatePage(outlet: outlet)),
    );
    if (updated == true && mounted) {
      await _load();
      _show('Outlet GPS location and shop image updated');
    }
  }

  void _show(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.danger : AppColors.success,
      duration: Duration(seconds: error ? 2 : 1),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Existing Outlets to Update'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ProCard(
              gradient: const LinearGradient(colors: [AppColors.primaryDark, AppColors.primary, AppColors.secondary]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Existing Outlets to Update', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                const Text('Only outlets without GPS are shown. Select an outlet to save its current GPS location and shop image.', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(.16), borderRadius: BorderRadius.circular(999)),
                  child: Text('${rows.length} outlets pending', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            if (loading)
              const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()))
            else if (rows.isEmpty)
              const ProCard(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(children: [
                    Icon(Icons.task_alt_rounded, color: AppColors.success, size: 52),
                    SizedBox(height: 12),
                    Text('No outlet is pending', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                    SizedBox(height: 6),
                    Text('All available outlets already have GPS information.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
                  ]),
                ),
              )
            else
              ...rows.map(_card),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _card(OutletMasterModel row) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _open(row),
        borderRadius: BorderRadius.circular(22),
        child: ProCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(.12), borderRadius: BorderRadius.circular(18)),
                child: const Icon(Icons.store_rounded, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(row.outletName.isEmpty ? 'Unnamed Outlet' : row.outletName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.text)),
                  const SizedBox(height: 4),
                  Text(row.outletCode.isEmpty ? 'Outlet ID: ${row.outletId}' : row.outletCode, style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.w800)),
                ]),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ]),
            if (row.routeName.isNotEmpty) _line(Icons.alt_route_rounded, 'Route', row.routeName),
            if (row.marketName.isNotEmpty) _line(Icons.store_mall_directory_rounded, 'Market', row.marketName),
            if (row.ownerName.isNotEmpty) _line(Icons.person_rounded, 'Owner', row.ownerName),
            if (row.contactNumber.isNotEmpty) _line(Icons.call_rounded, 'Mobile', row.contactNumber),
            if (row.shopAddress.isNotEmpty) _line(Icons.location_city_rounded, 'Address', row.shopAddress),
          ]),
        ),
      ),
    );
  }

  Widget _line(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 17, color: AppColors.muted),
        const SizedBox(width: 7),
        SizedBox(width: 68, child: Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w800))),
        Expanded(child: Text(value, style: const TextStyle(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.w800))),
      ]),
    );
  }
}
