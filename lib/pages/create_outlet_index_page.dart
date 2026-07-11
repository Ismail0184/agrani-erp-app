import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../models/outlet_master_model.dart';
import '../services/outlet_create_service.dart';
import '../widgets/pro_widgets.dart';
import 'app_drawer.dart';
import 'create_outlet_page.dart';

class CreateOutletIndexPage extends StatefulWidget {
  const CreateOutletIndexPage({super.key});

  @override
  State<CreateOutletIndexPage> createState() => _CreateOutletIndexPageState();
}

class _CreateOutletIndexPageState extends State<CreateOutletIndexPage> {
  List<OutletMasterModel> rows = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      rows = await OutletCreateService.instance.outletList();
    } catch (e) {
      if (mounted) _show('Outlet list load failed: $e', error: true);
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _create() async {
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const CreateOutletPage()));
    if (ok == true && mounted) {
      await _load();
      _show('Outlet created successfully');
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
      appBar: AppBar(title: const Text('Create Outlet'), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add_business_rounded),
        label: const Text('Create'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ProCard(
              gradient: const LinearGradient(colors: [AppColors.primaryDark, AppColors.primary, AppColors.secondary]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Outlet Creation', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                const Text('Outlet list from online sales_outlet_master for the logged-in app user.', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(.16), borderRadius: BorderRadius.circular(999)),
                  child: Text('${rows.length} outlets found', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            if (loading)
              const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()))
            else if (rows.isEmpty)
              ProCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    Container(width: 70, height: 70, decoration: BoxDecoration(color: AppColors.primary.withOpacity(.10), borderRadius: BorderRadius.circular(24)), child: const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 36)),
                    const SizedBox(height: 12),
                    const Text('No outlet found', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                    const SizedBox(height: 6),
                    const Text('Click Create to add a new outlet.', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 14),
                    FilledButton.icon(onPressed: _create, icon: const Icon(Icons.add_rounded), label: const Text('Create Outlet')),
                  ]),
                ),
              )
            else
              ...rows.map(_card),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _card(OutletMasterModel row) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ProCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 50, height: 50, decoration: BoxDecoration(color: AppColors.primary.withOpacity(.12), borderRadius: BorderRadius.circular(18)), child: const Icon(Icons.store_rounded, color: AppColors.primary)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(row.outletName.isEmpty ? 'Unnamed Outlet' : row.outletName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.text)),
              const SizedBox(height: 4),
              Text(row.marketName, style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.w800)),
            ])),
            StatusChip(row.status.isEmpty ? 'PENDING' : row.status),
          ]),
          const SizedBox(height: 12),
          _line(Icons.map_rounded, 'Territory', row.territoryName),
          _line(Icons.person_rounded, 'Owner', row.ownerName),
          _line(Icons.call_rounded, 'Mobile', row.contactNumber),
          _line(Icons.location_city_rounded, 'Shop Address', row.shopAddress.isEmpty ? '-' : row.shopAddress),
          _line(Icons.my_location_rounded, 'Map Location', row.latLngText),
          if (row.entryAt.isNotEmpty) _line(Icons.access_time_rounded, 'Created At', row.entryAt),
        ]),
      ),
    );
  }

  Widget _line(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 17, color: AppColors.muted),
        const SizedBox(width: 7),
        SizedBox(width: 92, child: Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w800))),
        Expanded(child: Text(value, style: const TextStyle(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.w800))),
      ]),
    );
  }
}
