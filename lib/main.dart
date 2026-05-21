// lib/main.dart
import 'package:flutter/material.dart';
import 'services/storage_service.dart';
import 'utils/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/customers_list_screen.dart';
import 'screens/customer_details_screen.dart';
import 'screens/return_invoice_screen.dart';
import 'screens/edit_transaction_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.instance.init();
  runApp(const ConstructionLedgerApp());
}

class ConstructionLedgerApp extends StatelessWidget {
  const ConstructionLedgerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'سجل العجاج',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'EG'),
      supportedLocales: const [Locale('ar', 'EG')],
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/': (context) => const HomeScreen(),
        '/customers': (context) => const CustomersListScreen(),
        '/customer_details': (context) => CustomerDetailsScreen(
              customerId: ModalRoute.of(context)!.settings.arguments as int,
            ),
        '/return_invoice': (context) => ReturnInvoiceScreen(
              customerId: ModalRoute.of(context)!.settings.arguments as int,
            ),
        '/edit_transaction': (context) => EditTransactionScreen(
              transactionId: ModalRoute.of(context)!.settings.arguments as int,
            ),
      },
    );
  }
}