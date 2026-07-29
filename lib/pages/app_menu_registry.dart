import 'package:flutter/material.dart';

import '../services/menu_permission_service.dart';
import 'audit_checklist_index_page.dart';
import 'collections_page.dart';
import 'create_outlet_index_page.dart';
import 'existing_outlet_update_index_page.dart';
import 'order_confirmation_page.dart';
import 'order_pending_delivery.dart';
import 'orders_page.dart';
import 'reports_page.dart';
import 'expenses_entry.dart';

class AppMenuRegistry {
  const AppMenuRegistry._();

  static Widget? pageForUrl(String url) {
    switch (MenuPermissionService.instance.normalizeUrl(url)) {
      case 'orders_page.dart':
        return const OrdersPage();
      case 'order_confirmation_page.dart':
        return const OrderConfirmationPage();
      case 'order_pending_delivery.dart':
        return const OrderPendingDeliveryPage();
      case 'collections_page.dart':
        return const CollectionsPage();
      case 'create_outlet_index_page.dart':
        return const CreateOutletIndexPage();
      case 'existing_outlet_update_index_page.dart':
        return const ExistingOutletUpdateIndexPage();
      case 'audit_checklist_index_page.dart':
        return const AuditChecklistIndexPage();
      case 'reports_page.dart':
        return const ReportsPage();
      case 'expenses_entry.dart':
        return const ExpensesEntryPage();
      default:
        return null;
    }
  }

  static IconData iconForUrl(String url) {
    switch (MenuPermissionService.instance.normalizeUrl(url)) {
      case 'orders_page.dart':
        return Icons.shopping_cart_rounded;
      case 'order_confirmation_page.dart':
        return Icons.verified_rounded;
      case 'order_pending_delivery.dart':
        return Icons.local_shipping_rounded;
      case 'collections_page.dart':
        return Icons.payments_rounded;
      case 'create_outlet_index_page.dart':
        return Icons.add_business_rounded;
      case 'existing_outlet_update_index_page.dart':
        return Icons.edit_location_alt_rounded;
      case 'audit_checklist_index_page.dart':
        return Icons.fact_check_rounded;
      case 'reports_page.dart':
        return Icons.analytics_rounded;
      case 'expenses_entry.dart':
        return Icons.receipt_long_rounded;
      default:
        return Icons.apps_rounded;
    }
  }
}
