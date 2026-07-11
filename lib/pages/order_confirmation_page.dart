import 'package:flutter/material.dart';
import 'orders_page.dart';

class OrderConfirmationPage extends StatelessWidget {
  const OrderConfirmationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const OrdersPage(fixedStatus: 'UNCHECKED');
  }
}
