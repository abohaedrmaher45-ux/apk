import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/models/account_models.dart';
import '../../data/repository/account_repository.dart';
import '../bloc/orders_bloc.dart';
import '../utils/order_status_mapper.dart';
import '../pages/orders_page.dart';
import '../pages/order_detail_page.dart';
import 'section_header.dart';

/// Recent Orders horizontal scroll section
/// Figma: node-id=220-6589
class RecentOrdersSection extends StatelessWidget {
  final List<RecentOrder> orders;

  const RecentOrdersSection({super.key, required this.orders});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SectionHeader(
              title: l10n.accountRecentOrders,
              onViewAll: orders.isNotEmpty
                  ? () {
                      final repository = context.read<AccountRepository>();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RepositoryProvider.value(
                            value: repository,
                            child: BlocProvider(
                              create: (_) =>
                                  OrdersBloc(repository: repository)
                                    ..add(const LoadOrders()),
                              child: const OrdersPage(),
                            ),
                          ),
                        ),
                      );
                    }
                  : null,
            ),
          ),
          const SizedBox(height: 2),
          if (orders.isEmpty)
            _buildEmptyState(context)
          else
            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: orders.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final order = orders[index];
                  return GestureDetector(
                    onTap: () {
                      // incrementId is the numeric order ID used by the API
                      // order.id may be a base64-encoded GraphQL ID
                      final numId =
                          order.incrementId ?? int.tryParse(order.id ?? '');
                      debugPrint(
                        '📦 RecentOrder tap: id=${order.id}, '
                        'incrementId=${order.incrementId}, numId=$numId',
                      );
                      if (numId != null) {
                        final repo = context.read<AccountRepository>();
                        OrderDetailPage.navigate(
                          context,
                          orderId: numId,
                          orderNumber: order.orderNumber,
                          repository: repo,
                        );
                      }
                    },
                    child: _buildOrderCard(context, order),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.neutral800 : AppColors.neutral100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? AppColors.neutral700 : AppColors.neutral200,
          ),
        ),
        child: Center(
          child: Text(
            l10n.accountNoRecentOrders,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 14,
              color: isDark ? AppColors.neutral400 : AppColors.neutral500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, RecentOrder order) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      width: 270,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.neutral800 : AppColors.neutral100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.neutral700 : AppColors.neutral200,
        ),
      ),
      child: Row(
        children: [
          // Order details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Order number
                Text(
                  order.orderNumber,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: isDark ? AppColors.neutral200 : AppColors.neutral900,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                // Status chip + date
                Row(
                  children: [
                    _buildStatusChip(context, order.status),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        order.formattedDate,
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontWeight: FontWeight.w400,
                          fontSize: 14,
                          color: isDark
                              ? AppColors.neutral300
                              : AppColors.neutral900,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                // Total + item count
                Text(
                  l10n.accountOrderTotalItems(order.formattedTotal, order.itemCount),
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.w400,
                    fontSize: 14,
                    color: isDark ? AppColors.neutral300 : AppColors.neutral900,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, String status) {
    final l10n = AppLocalizations.of(context)!;
    Color bgColor;
    Color borderColor;
    Color textColor;

    final displayStatus = OrderStatusMapper.resolve(status);
    final String label = OrderStatusMapper.label(displayStatus, l10n);

    switch (displayStatus) {
      case OrderDisplayStatus.newOrder:
        bgColor = const Color(0xFFE9F0FF);
        borderColor = const Color(0xFFC9DBFF);
        textColor = const Color(0xFF3B6FE0);
        break;
      case OrderDisplayStatus.preparing:
        bgColor = const Color(0xFFF1EAFE);
        borderColor = const Color(0xFFD6B4FE);
        textColor = const Color(0xFF7C4DD6);
        break;
      case OrderDisplayStatus.ready:
        bgColor = const Color(0xFFFFF3E0);
        borderColor = const Color(0xFFFFD9A0);
        textColor = const Color(0xFFC77700);
        break;
      case OrderDisplayStatus.outForDelivery:
        bgColor = const Color(0xFFE7F3FF);
        borderColor = const Color(0xFFB6DBF8);
        textColor = const Color(0xFF1F76C4);
        break;
      case OrderDisplayStatus.delivered:
        bgColor = const Color(0xFFE6F6EC);
        borderColor = const Color(0xFFBDE5CB);
        textColor = const Color(0xFF2E9E5B);
        break;
      case OrderDisplayStatus.canceled:
        bgColor = const Color(0xFFF7E9F2);
        borderColor = const Color(0xFFE6C2D8);
        textColor = const Color(0xFFB13E7E);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Roboto',
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: textColor,
        ),
      ),
    );
  }
}
