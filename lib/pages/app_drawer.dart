import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../services/auth_service.dart';
import '../services/session_service.dart';
import 'collections_page.dart';
import 'create_outlet_index_page.dart';
import 'dashboard_page.dart';
import 'login_page.dart';
import 'order_confirmation_page.dart';
import 'orders_page.dart';
import 'sync_page.dart';
import 'reports_page.dart';
import 'audit_checklist_index_page.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  String name = '';
  String photo = '';
  String department = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    name = await SessionService.instance.fullName();
    photo = await SessionService.instance.photoUrl();
    department = await SessionService.instance.department();
    if (mounted) setState(() {});
  }

  void _go(Widget page) {
    Navigator.pop(context);
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 48, 18, 20),
            decoration: const BoxDecoration(gradient: LinearGradient(colors: [AppColors.primaryDark, AppColors.primary])),
            child: Row(
              children: [
                CircleAvatar(radius: 34, backgroundImage: NetworkImage(photo), onBackgroundImageError: (_, __) {}),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name.isEmpty ? 'Agrani User' : name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
                    const SizedBox(height: 4),
                    const Text('Mobile ERP', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10),
              children: [
                _item(Icons.dashboard_rounded, 'Dashboard', () => _go(const DashboardPage())),
                _item(Icons.shopping_cart_rounded, 'Orders', () => _go(const OrdersPage())),
                _item(Icons.verified_rounded, 'Delivered Confirmation', () => _go(const OrderConfirmationPage())),
                _item(Icons.payments_rounded, 'Collection', () => _go(const CollectionsPage())),
                _item(Icons.add_business_rounded, 'Create Outlet', () => _go(const CreateOutletIndexPage())),
                if (department.trim().toLowerCase() == 'audit')
                  _item(Icons.fact_check_rounded, 'Audit Checklist', () => _go(const AuditChecklistIndexPage())),
                _item(Icons.sync_rounded, 'Synchronization', () => _go(const SyncPage())),
                _item(Icons.analytics_rounded, 'Reports', () => _go(const ReportsPage())),
                const Divider(height: 18),
                _logoutItem(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _logoutItem() {
    return ListTile(
      leading: const Icon(Icons.logout_rounded, color: AppColors.danger),
      title: const Text('Logout', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800)),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.danger),
      onTap: () async {
        await AuthService.instance.logout();
        if (!context.mounted) return;
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false);
      },
    );
  }

  Widget _item(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
