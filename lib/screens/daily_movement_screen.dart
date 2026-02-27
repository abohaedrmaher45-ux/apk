import 'package:flutter/material.dart';
import '../services/store_db_service.dart';
import 'seller_management_screen.dart';
import 'daily_movement/yield_screen.dart' as DailyMovementYield;
import 'daily_movement/purchases_screen.dart';
import 'daily_movement/sales_screen.dart';
import 'daily_movement/receipt_screen.dart';
import 'daily_movement/box_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'bait_screen.dart';
import 'daily_movement/invoice_type_selection_screen.dart';

class DailyMovementScreen extends StatefulWidget {
  final String selectedDate;
  final String storeType;
  final String sellerName;

  const DailyMovementScreen({
    super.key,
    required this.selectedDate,
    required this.storeType,
    required this.sellerName,
  });

  @override
  State<DailyMovementScreen> createState() => _DailyMovementScreenState();
}

class _DailyMovementScreenState extends State<DailyMovementScreen> {
  String _storeName = '';

  @override
  void initState() {
    super.initState();
    _loadStoreName();
  }

  Future<void> _loadStoreName() async {
    final storeDbService = StoreDbService();
    final savedStoreName = await storeDbService.getStoreName();
    setState(() {
      _storeName = savedStoreName ?? widget.storeType;
    });
  }

  void _handleBackButton() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
              'الحركة اليومية لتاريخ ${widget.selectedDate} البائع ${widget.sellerName}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: Colors.green[600],
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBackButton,
          ),
        ),
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 2, horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  boxShadow: [
                    BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 3)
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10.0, vertical: 7.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildMenuButton(context,
                                icon: Icons.inventory,
                                label: 'الاستلام',
                                color: Colors.blue[700]!, onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => ReceiptScreen(
                                      sellerName: widget.sellerName,
                                      selectedDate: widget.selectedDate,
                                      storeName: _storeName),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(width: 12.0),
                          Expanded(
                            child: _buildMenuButton(context,
                                icon: Icons.point_of_sale,
                                label: 'المبيعات',
                                color: Colors.orange[700]!, onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => SalesScreen(
                                      sellerName: widget.sellerName,
                                      selectedDate: widget.selectedDate,
                                      storeName: _storeName),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(width: 12.0),
                          Expanded(
                            child: _buildMenuButton(context,
                                icon: Icons.shopping_cart,
                                label: 'المشتريات',
                                color: Colors.red[700]!, onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => PurchasesScreen(
                                      sellerName: widget.sellerName,
                                      selectedDate: widget.selectedDate,
                                      storeName: _storeName),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(width: 12.0),
                          Expanded(
                            child: _buildMenuButton(context,
                                icon: Icons.receipt_long,
                                label: 'الفواتير',
                                color: Colors.indigo[700]!, onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      InvoiceTypeSelectionScreen(
                                    selectedDate: widget.selectedDate,
                                    storeName: _storeName,
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12.0), // مسافة بين السطرين
                      // --- السطر الثاني (4 أزرار) ---
                      Row(
                        children: [
                          Expanded(
                            child: _buildMenuButton(context,
                                icon: Icons.account_balance,
                                label: 'الصندوق',
                                color: Colors.blueGrey[600]!, onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => BoxScreen(
                                      sellerName: widget.sellerName,
                                      selectedDate: widget.selectedDate,
                                      storeName: _storeName),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(width: 12.0),
                          Expanded(
                            child: _buildMenuButton(context,
                                icon: Icons.grain,
                                label: 'الغلة',
                                color: Colors.purple[700]!, onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      DailyMovementYield.YieldScreen(
                                    sellerName: widget.sellerName,
                                    password: '******',
                                    selectedDate: widget.selectedDate,
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(width: 12.0),
                          Expanded(
                            child: _buildMenuButton(context,
                                icon: Icons.inventory_2,
                                label: 'البايت',
                                color: Colors.teal[700]!, onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => BaitScreen(
                                    selectedDate: widget.selectedDate,
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(width: 12.0),
                          Expanded(
                            child: _buildMenuButton(context,
                                icon: Icons.settings,
                                label: 'الخدمات',
                                color: Colors.grey[600]!, onTap: () async {
                              final isAdmin =
                                  await _isAdminSeller(widget.sellerName);
                              if (isAdmin) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        SellerManagementScreen(
                                      currentStoreName: _storeName,
                                      onLogout: () {
                                        Navigator.of(context)
                                            .popUntil((route) => route.isFirst);
                                      },
                                    ),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'عفواً، هذه الخدمة متاحة فقط للإدارة'),
                                    backgroundColor: Colors.red,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            }),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context,
      {required IconData icon,
      required String label,
      required Color color,
      VoidCallback? onTap}) {
    final isServicesButton = label == 'الخدمات';
    // تعديل ارتفاع الزر ليتناسب مع وجود 4 أزرار
    final buttonHeight = (MediaQuery.of(context).size.width / 4) / 1.5;

    return FutureBuilder<bool>(
        future: isServicesButton
            ? _isAdminSeller(widget.sellerName)
            : Future.value(true),
        builder: (context, snapshot) {
          final isAdmin = snapshot.data ?? false;
          final isEnabled = !isServicesButton || isAdmin;

          return InkWell(
            onTap: isEnabled ? onTap : null,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: buttonHeight,
              decoration: BoxDecoration(
                color: isEnabled ? color : Colors.grey[400],
                borderRadius: BorderRadius.circular(12),
                boxShadow: isEnabled
                    ? [
                        BoxShadow(
                            color: color.withOpacity(0.4),
                            spreadRadius: 1,
                            blurRadius: 3)
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon,
                      size: 32,
                      color: isEnabled ? Colors.white : Colors.grey[200]),
                  const SizedBox(height: 5),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isEnabled ? Colors.white : Colors.grey[200],
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isServicesButton && isAdmin)
                    const Padding(
                      padding: EdgeInsets.only(top: 4.0),
                      child: Icon(
                        Icons.star,
                        size: 12,
                        color: Colors.yellow,
                      ),
                    ),
                ],
              ),
            ),
          );
        });
  }

  Future<bool> _isAdminSeller(String sellerName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final adminSeller = prefs.getString('admin_seller');
      if (adminSeller == null) {
        final accountsJson = prefs.getString('accounts');
        if (accountsJson != null) {
          final accounts = json.decode(accountsJson) as Map<String, dynamic>;
          if (accounts.isNotEmpty) {
            final firstSeller = accounts.keys.first;
            await prefs.setString('admin_seller', firstSeller);
            return firstSeller == sellerName;
          }
        }
        return false;
      }
      return adminSeller == sellerName;
    } catch (e) {
      print('خطأ في التحقق من الادمن: $e');
      return false;
    }
  }
}
