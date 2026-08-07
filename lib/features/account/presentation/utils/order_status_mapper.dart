import '../../../../l10n/app_localizations.dart';

/// The customer-facing order states requested by the client.
///
/// Bagisto's default order statuses are fewer
/// (pending / pending_payment / processing / completed / canceled / closed /
/// fraud), so this enum defines the richer set the customer should see:
///   جديد / قيد التجهيز / جاهز / قيد التوصيل / تم التسليم / ملغي
enum OrderDisplayStatus {
  /// جديد
  newOrder,

  /// قيد التجهيز
  preparing,

  /// جاهز
  ready,

  /// قيد التوصيل
  outForDelivery,

  /// تم التسليم
  delivered,

  /// ملغي
  canceled,
}

/// Maps raw Bagisto order status strings (plus shipment presence) onto the
/// six customer-facing states, and provides localized labels + timeline
/// positioning.
///
/// This is a presentation-only mapping layer. It does NOT change any backend
/// logic; it only interprets the data the API already returns. If the backend
/// later introduces dedicated custom statuses (e.g. `ready`,
/// `out_for_delivery`, `delivered`), they are recognized here automatically.
class OrderStatusMapper {
  const OrderStatusMapper._();

  /// Ordered list of the states shown in the tracking timeline
  /// (the terminal `canceled` state is handled separately).
  static const List<OrderDisplayStatus> timelineSteps = [
    OrderDisplayStatus.newOrder,
    OrderDisplayStatus.preparing,
    OrderDisplayStatus.ready,
    OrderDisplayStatus.outForDelivery,
    OrderDisplayStatus.delivered,
  ];

  /// Resolve the raw Bagisto status (and whether a shipment exists) into one of
  /// the six customer-facing states.
  ///
  /// [rawStatus] is the order's `status` string from the API.
  /// [hasShipment] indicates at least one shipment record exists on the order.
  /// [isFullyShipped] indicates every ordered item has been shipped
  /// (optional refinement; defaults to [hasShipment]).
  static OrderDisplayStatus resolve(
    String rawStatus, {
    bool hasShipment = false,
    bool? isFullyShipped,
  }) {
    final s = rawStatus.trim().toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_');
    final shipped = isFullyShipped ?? hasShipment;

    switch (s) {
      // ── Canceled / terminal-negative ──
      case 'canceled':
      case 'cancelled':
      case 'closed':
      case 'fraud':
        return OrderDisplayStatus.canceled;

      // ── New ──
      case 'new':
      case 'pending':
      case 'pending_payment':
        return OrderDisplayStatus.newOrder;

      // ── Preparing ──
      case 'processing':
        // If a shipment has already been created for a processing order,
        // treat it as out for delivery; otherwise it is being prepared.
        return hasShipment
            ? OrderDisplayStatus.outForDelivery
            : OrderDisplayStatus.preparing;

      // ── Ready (custom status, if configured in the backend) ──
      case 'ready':
      case 'ready_to_ship':
      case 'ready_for_pickup':
      case 'packed':
        return OrderDisplayStatus.ready;

      // ── Out for delivery (custom status, if configured) ──
      case 'shipped':
      case 'out_for_delivery':
      case 'on_the_way':
      case 'in_transit':
        return OrderDisplayStatus.outForDelivery;

      // ── Delivered / completed ──
      case 'completed':
      case 'delivered':
        return OrderDisplayStatus.delivered;

      default:
        // Unknown status: fall back using shipment presence as a hint.
        if (shipped) return OrderDisplayStatus.outForDelivery;
        return OrderDisplayStatus.preparing;
    }
  }

  /// Localized label for a display status.
  static String label(OrderDisplayStatus status, AppLocalizations l10n) {
    switch (status) {
      case OrderDisplayStatus.newOrder:
        return l10n.orderStatusNew;
      case OrderDisplayStatus.preparing:
        return l10n.orderStatusPreparing;
      case OrderDisplayStatus.ready:
        return l10n.orderStatusReady;
      case OrderDisplayStatus.outForDelivery:
        return l10n.orderStatusOutForDelivery;
      case OrderDisplayStatus.delivered:
        return l10n.orderStatusDelivered;
      case OrderDisplayStatus.canceled:
        return l10n.orderStatusCanceled;
    }
  }

  /// Whether this status represents a canceled order.
  static bool isCanceled(OrderDisplayStatus status) =>
      status == OrderDisplayStatus.canceled;

  /// Zero-based index of the status within [timelineSteps].
  /// Returns 0 for canceled orders (the timeline is replaced by a cancel
  /// banner in that case).
  static int timelineIndex(OrderDisplayStatus status) {
    final i = timelineSteps.indexOf(status);
    return i < 0 ? 0 : i;
  }
}
