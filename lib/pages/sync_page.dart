import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../core/local_db.dart';
import '../services/master_data_service.dart';
import '../services/sync_service.dart';
import '../widgets/pro_widgets.dart';
import 'app_drawer.dart';

class SyncPage extends StatefulWidget {
  const SyncPage({super.key});

  @override
  State<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends State<SyncPage> {
  int pending = 0;
  bool loading = false;
  Map<String, int>? result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    pending = await LocalDb.instance.pendingCount();
    if (mounted) setState(() {});
  }

  Future<void> _sync() async {
    setState(() => loading = true);
    try {
      result = await SyncService.instance.syncAll();
      await MasterDataService.instance.downloadMasterData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Synchronization completed')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
    } finally {
      loading = false;
      await _load();
    }
  }

  Future<void> _downloadMaster() async {
    setState(() => loading = true);
    try {
      await MasterDataService.instance.downloadMasterData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Master data updated')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(title: const Text('Synchronization')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ProInfoTile(icon: Icons.sync_problem_rounded, title: 'Pending Records', value: '$pending', color: AppColors.purple),
          const SizedBox(height: 16),
          ProCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SectionTitle('Manual Sync', subtitle: 'Upload attendance, GPS, orders and collections. Download master data.'),
            FilledButton.icon(onPressed: loading ? null : _sync, icon: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.cloud_sync_rounded), label: const Text('Sync Now')),
            const SizedBox(height: 10),
            OutlinedButton.icon(onPressed: loading ? null : _downloadMaster, icon: const Icon(Icons.download_rounded), label: const Text('Download Master Data')),
          ])),
          if (result != null) ...[
            const SizedBox(height: 16),
            ProCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SectionTitle('Last Sync Result'),
              Text('Attendance: ${result!['attendance'] ?? 0}'),
              Text('GPS: ${result!['gps'] ?? 0}'),
              Text('Orders: ${result!['orders'] ?? 0}'),
              Text('Collections: ${result!['collections'] ?? 0}'),
            ])),
          ],
        ],
      ),
    );
  }
}
