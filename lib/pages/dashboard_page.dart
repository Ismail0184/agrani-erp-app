import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/app_theme.dart';
import '../core/local_db.dart';
import '../services/gps_service.dart';
import '../services/session_service.dart';
import '../widgets/pro_widgets.dart';
import 'app_drawer.dart';
import 'collections_page.dart';
import 'create_outlet_index_page.dart';
import 'order_confirmation_page.dart';
import 'orders_page.dart';
import 'sync_page.dart';
import 'reports_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String name = '';
  String photo = '';
  String companyName = '';
  Map<String, dynamic>? attendance;
  Map<String, int> counts = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    name = await SessionService.instance.fullName();
    photo = await SessionService.instance.photoUrl();
    companyName = await SessionService.instance.companyName();
    attendance = await LocalDb.instance.todayAttendance();
    attendance ??= await SessionService.instance.todayAttendanceCache();
    counts = await LocalDb.instance.dashboardCounts();
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppDrawer(),
      bottomNavigationBar: _quickActionBar(),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _branchHeader()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 104),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _quickMenuGrid(),
                  const SizedBox(height: 14),
                  _billingStyleSummary(),
                  const SizedBox(height: 14),
                  _miniStatusRow(),
                  if (loading) const Padding(padding: EdgeInsets.only(top: 18), child: LinearProgressIndicator()),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _branchHeader() {
    final title = companyName.trim().isEmpty ? 'Agrani ERP' : companyName.trim();
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF3F73AD), Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
          child: Row(children: [
            IconButton(
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 28),
              tooltip: 'Menu',
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20),
              ),
            ),
            IconButton(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 28),
              tooltip: 'Refresh',
            ),
          ]),
        ),
      ),
    );
  }

  Widget _profileSummary() {
    final login = '${attendance?['login_time'] ?? '-'}';
    final today = DateFormat('EEE, dd MMM yyyy').format(DateTime.now());

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary.withOpacity(.08), AppColors.secondary.withOpacity(.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 25,
          backgroundColor: Colors.white,
          backgroundImage: photo.trim().isEmpty ? null : NetworkImage(photo),
          onBackgroundImageError: (_, __) {},
          child: photo.trim().isEmpty ? const Icon(Icons.person_rounded, color: AppColors.muted, size: 28) : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(
              name.isEmpty ? 'Agrani User' : name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w900, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.access_time_rounded, color: AppColors.primary, size: 14),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Attendance: $login',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w800, fontSize: 11),
                ),
              ),
            ]),
            const SizedBox(height: 3),
            Row(children: [
              const Icon(Icons.calendar_month_rounded, color: AppColors.secondary, size: 14),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  today,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w800, fontSize: 11),
                ),
              ),
            ]),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.primary.withOpacity(.18)),
          ),
          child: const Text('ERP', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 11)),
        ),
      ]),
    );
  }

  Widget _quickMenuGrid() {
    final items = [
      _DashAction('Orders', Icons.shopping_cart_rounded, AppColors.secondary, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersPage()))),
      _DashAction('Delivery', Icons.verified_rounded, AppColors.success, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderConfirmationPage()))),
      _DashAction('Collection', Icons.payments_rounded, AppColors.accent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CollectionsPage()))),
      _DashAction('Outlet', Icons.add_business_rounded, AppColors.purple, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateOutletIndexPage()))),
      _DashAction('Sync', Icons.sync_rounded, AppColors.primary, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SyncPage()))),
      _DashAction('Reports', Icons.analytics_rounded, AppColors.secondary, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsPage()))),
      _DashAction('GPS', Icons.my_location_rounded, AppColors.danger, () async {
        await GpsService.instance.captureCurrentPoint();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('GPS point saved for sync')));
        _load();
      }),
      _DashAction('Refresh', Icons.refresh_rounded, AppColors.primaryDark, _load),
    ];

    return ProCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _profileSummary(),

        // Keep only a small responsive gap between user info and quick actions.
        // GridView was creating large unused vertical space on different phones.
        const SizedBox(height: 10),

        _quickActionRows(items),
      ]),
    );
  }

  Widget _quickActionRows(List<_DashAction> items) {
    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 340;
      final rowHeight = compact ? 64.0 : 68.0;
      final rowGap = compact ? 6.0 : 8.0;

      return Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          height: rowHeight,
          child: Row(children: [
            for (int i = 0; i < 4; i++)
              Expanded(child: _quickMenuItem(items[i], compact: compact)),
          ]),
        ),
        SizedBox(height: rowGap),
        SizedBox(
          height: rowHeight,
          child: Row(children: [
            for (int i = 4; i < 8; i++)
              Expanded(child: _quickMenuItem(items[i], compact: compact)),
          ]),
        ),
      ]);
    });
  }

  Widget _quickMenuItem(_DashAction item, {bool compact = false}) {
    final iconBox = compact ? 36.0 : 39.0;
    final iconSize = compact ? 21.0 : 23.0;
    final titleSize = compact ? 9.8 : 10.5;

    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: iconBox,
          height: iconBox,
          decoration: BoxDecoration(color: item.color.withOpacity(.12), borderRadius: BorderRadius.circular(15)),
          child: Icon(item.icon, color: item.color, size: iconSize),
        ),
        const SizedBox(height: 4),
        Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.w800, color: AppColors.text),
        ),
      ]),
    );
  }

  Widget _billingStyleSummary() {
    final orders = counts['todayOrders'] ?? 0;
    final collections = counts['todayCollections'] ?? 0;
    final unchecked = counts['uncheckedOrders'] ?? 0;
    final pending = counts['pendingSync'] ?? 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(.10), borderRadius: BorderRadius.circular(15)),
            child: const Icon(Icons.insights_rounded, color: AppColors.primary, size: 21),
          ),
          const SizedBox(width: 9),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Today\'s Data Status', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w900, fontSize: 15)),
              SizedBox(height: 2),
              Text('Live summary from today\'s activity', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700, fontSize: 11)),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _summaryCell('Today Orders', '$orders', Icons.shopping_bag_rounded, AppColors.secondary)),
          const SizedBox(width: 10),
          Expanded(child: _summaryCell('Collections', '$collections', Icons.account_balance_wallet_rounded, AppColors.success)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _summaryCell('Unchecked', '$unchecked', Icons.pending_actions_rounded, AppColors.accent)),
          const SizedBox(width: 10),
          Expanded(child: _summaryCell('Pending Sync', '$pending', Icons.sync_problem_rounded, AppColors.purple)),
        ]),
        const SizedBox(height: 12),
        _orderCollectionStatistics(orders, collections),
      ]),
    );
  }

  Widget _summaryCell(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        color: color.withOpacity(.035),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(.08)),
      ),
      child: Row(children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: color, size: 22)),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700, fontSize: 10.5)),
          const SizedBox(height: 1),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w900, fontSize: 17)),
        ])),
      ]),
    );
  }

  Widget _orderCollectionStatistics(int orders, int collections) {
    final maxValue = [orders, collections, 1].reduce((a, b) => a > b ? a : b);
    final orderRatio = (orders / maxValue).clamp(0.0, 1.0);
    final collectionRatio = (collections / maxValue).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.secondary.withOpacity(.055), AppColors.success.withOpacity(.045)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Order vs Collection Statistics', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w900, fontSize: 13)),
        const SizedBox(height: 9),
        _statProgressRow('Orders', orders, orderRatio, AppColors.secondary),
        const SizedBox(height: 8),
        _statProgressRow('Collections', collections, collectionRatio, AppColors.success),
        const SizedBox(height: 12),
        _orderCollectionMiniChart(orders, collections),
      ]),
    );
  }

  Widget _statProgressRow(String title, int value, double ratio, Color color) {
    return Row(children: [
      SizedBox(width: 78, child: Text(title, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w800, fontSize: 11))),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 9,
            backgroundColor: color.withOpacity(.10),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Text('$value', style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12)),
    ]);
  }

  Widget _orderCollectionMiniChart(int orders, int collections) {
    final maxValue = [orders, collections, 1].reduce((a, b) => a > b ? a : b).toDouble();
    final orderHeight = 12 + ((orders / maxValue) * 54);
    final collectionHeight = 12 + ((collections / maxValue) * 54);

    return Container(
      height: 118,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.62),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(child: _chartBar('Orders', orders, orderHeight, AppColors.secondary)),
        const SizedBox(width: 14),
        Expanded(child: _chartBar('Collections', collections, collectionHeight, AppColors.success)),
      ]),
    );
  }

  Widget _chartBar(String title, int value, double height, Color color) {
    return Column(mainAxisAlignment: MainAxisAlignment.end, children: [
      Text('$value', style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12)),
      const SizedBox(height: 4),
      AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        width: 46,
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color.withOpacity(.55), color], begin: Alignment.topCenter, end: Alignment.bottomCenter),
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      const SizedBox(height: 6),
      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w800, fontSize: 11)),
    ]);
  }

  Widget _miniStatusRow() {
    final status = '${attendance?['attendance_status'] ?? '-'}';
    final sync = '${attendance?['sync_status'] ?? '-'}';
    return Row(children: [
      Expanded(child: _smallCard('Attendance', status, Icons.verified_user_rounded, AppColors.success)),
      const SizedBox(width: 10),
      Expanded(child: _smallCard('Sync Status', sync, Icons.cloud_sync_rounded, AppColors.secondary)),
    ]);
  }

  Widget _smallCard(String title, String value, IconData icon, Color color) {
    return ProCard(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700, fontSize: 11)),
          const SizedBox(height: 3),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
        ])),
      ]),
    );
  }

  Widget _quickActionBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 5, 8, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.08), blurRadius: 18, offset: const Offset(0, -8))],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, crossAxisAlignment: CrossAxisAlignment.end, children: [
          _bottomAction('Home', Icons.home_rounded, _load),
          _bottomAction('Collect', Icons.payments_rounded, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CollectionsPage()))),
          _bottomAction('Order', Icons.add_rounded, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersPage())), selected: true),
          _bottomAction('Sync', Icons.sync_rounded, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SyncPage()))),
          _bottomAction('More', Icons.menu_rounded, () => _scaffoldKey.currentState?.openDrawer()),
        ]),
      ),
    );
  }

  Widget _bottomAction(String title, IconData icon, VoidCallback onTap, {bool selected = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(selected ? 28 : 18),
      child: SizedBox(
        width: selected ? 74 : 58,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Transform.translate(
            offset: Offset(0, selected ? -13 : 0),
            child: Container(
              width: selected ? 58 : 31,
              height: selected ? 58 : 31,
              decoration: BoxDecoration(
                shape: selected ? BoxShape.circle : BoxShape.rectangle,
                gradient: selected ? const LinearGradient(colors: [Color(0xFF8B7CF6), AppColors.secondary], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
                color: selected ? null : Colors.transparent,
                borderRadius: selected ? null : BorderRadius.circular(14),
                boxShadow: selected ? [BoxShadow(color: AppColors.secondary.withOpacity(.26), blurRadius: 18, offset: const Offset(0, 9))] : null,
              ),
              child: Icon(icon, color: selected ? Colors.white : AppColors.primary, size: selected ? 30 : 22),
            ),
          ),
          SizedBox(height: selected ? 0 : 2),
          Transform.translate(
            offset: Offset(0, selected ? -8 : 0),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: selected ? 11 : 10.5, fontWeight: FontWeight.w900, color: selected ? AppColors.secondary : AppColors.text),
            ),
          ),
        ]),
      ),
    );
  }
}

class _DashAction {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _DashAction(this.title, this.icon, this.color, this.onTap);
}
