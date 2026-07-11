import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/api_client.dart';
import '../core/app_theme.dart';
import '../widgets/pro_widgets.dart';
import 'gps_track_map_page.dart';

class ReportGpsTrackPage extends StatefulWidget {
  const ReportGpsTrackPage({super.key});

  @override
  State<ReportGpsTrackPage> createState() => _ReportGpsTrackPageState();
}

class _ReportGpsTrackPageState extends State<ReportGpsTrackPage> {
  final df = DateFormat('yyyy-MM-dd');
  late String date;
  List<Map<String, dynamic>> rows = [];
  bool loading = false;

  @override
  void initState() {
    super.initState();
    date = df.format(DateTime.now());
  }

  Future<void> _viewOnMap() async {
    setState(() => loading = true);
    try {
      final data = await ApiClient.instance.get('gps_history', query: {'date': date});
      rows = (data['rows'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (!mounted) return;
      if (rows.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No GPS history found for $date')),
        );
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GpsTrackMapPage(date: date, points: rows)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('GPS history load failed: $e')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _pickDate() async {
    final current = DateTime.tryParse(date) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: current,
    );
    if (picked == null) return;
    setState(() => date = df.format(picked));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report: GPS Track')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ProCard(
            gradient: const LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('GPS Track Report', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(
                'Select date and view logged-in user movement on map.',
                style: TextStyle(color: Colors.white.withOpacity(.86), fontWeight: FontWeight.w700),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          ProCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SectionTitle('Filter GPS Track', subtitle: 'Only date selection is required. Outlet search is removed for GPS Track.'),
              _dateBox('Tracking Date', date, _pickDate),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: loading ? null : _viewOnMap,
                  icon: loading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.map_rounded),
                  label: Text(loading ? 'Loading GPS Track...' : 'View on Map'),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          ProCard(
            color: const Color(0xFFF0FDFA),
            child: Row(children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(.14), borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.info_rounded, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'This report will load GPS points from the online database for the logged-in user only.',
                  style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _dateBox(String label, String value, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: InputDecorator(
          decoration: const InputDecoration(labelText: 'Tracking Date', prefixIcon: Icon(Icons.calendar_month_rounded)),
          child: Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
      );
}
