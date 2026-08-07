// ╔══════════════════════════════════════════════════════════════════════╗
// ║  PREVIEW / MOCK DATA — TEMPORARY UI PREVIEW HELPER                      ║
// ║                                                                        ║
// ║  Purpose: lets you SEE the redesigned screens before the backend is    ║
// ║  connected. It is 100% self-contained and touches NO Bloc, repository, ║
// ║  GraphQL, or function names.                                           ║
// ║                                                                        ║
// ║  HOW TO TURN IT OFF (one line):                                        ║
// ║      set  kUsePreviewData = false;                                     ║
// ║  HOW TO REMOVE COMPLETELY:                                             ║
// ║      delete this file, then delete the few `if (kUsePreviewData)`      ║
// ║      blocks in home_page.dart and category_page.dart (each is marked   ║
// ║      with the comment  // PREVIEW-ONLY  so they are easy to find).     ║
// ║                                                                        ║
// ║  Behaviour: the preview content is only shown on the ERROR / no-       ║
// ║  connection branch of each screen. The moment the real backend         ║
// ║  returns data, the real data is shown instead — so this never fights   ║
// ║  the backend integration.                                             ║
// ╚══════════════════════════════════════════════════════════════════════╝

import 'package:flutter/material.dart';

import '../theme/sentry_ui.dart';
import '../../features/home/data/models/home_models.dart';
import '../../features/category/data/models/category_model.dart';
import '../../features/category/data/models/product_model.dart';
import '../../features/account/data/models/account_models.dart';

/// MASTER SWITCH. Set to `false` (or delete this file) to disable all preview
/// data and return to pure backend-driven behaviour.
const bool kUsePreviewData = false;

/// ── Placeholder product image ──
/// A simple icon-on-tint box used wherever a product image would go, so we
/// don't need any network images while previewing.
class PreviewImagePlaceholder extends StatelessWidget {
  const PreviewImagePlaceholder({
    super.key,
    this.icon = Icons.restaurant,
    this.size,
    this.radius = 12,
  });

  final IconData icon;
  final double? size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            SentryPalette.softViolet.withValues(alpha: 0.35),
            SentryPalette.blue.withValues(alpha: 0.30),
          ],
        ),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(
        icon,
        color: SentryPalette.violet.withValues(alpha: 0.8),
        size: 30,
      ),
    );
  }
}

/// Central holder for all mock data used by the preview screens.
class PreviewData {
  PreviewData._();

  // ──────────────────────────────────────────────────────────────────────
  // HOME SCREEN MOCK DATA
  // ──────────────────────────────────────────────────────────────────────

  static List<HomeCategory> homeCategories() => const [
    HomeCategory(
      id: 'pc-1',
      numericId: 1,
      name: 'فواكه وخضار',
      slug: 'fruits-veg',
      position: 1,
    ),
    HomeCategory(
      id: 'pc-2',
      numericId: 2,
      name: 'ألبان وأجبان',
      slug: 'dairy',
      position: 2,
    ),
    HomeCategory(
      id: 'pc-3',
      numericId: 3,
      name: 'مخبوزات',
      slug: 'bakery',
      position: 3,
    ),
    HomeCategory(
      id: 'pc-4',
      numericId: 4,
      name: 'مشروبات',
      slug: 'drinks',
      position: 4,
    ),
    HomeCategory(
      id: 'pc-5',
      numericId: 5,
      name: 'وجبات خفيفة',
      slug: 'snacks',
      position: 5,
    ),
    HomeCategory(
      id: 'pc-6',
      numericId: 6,
      name: 'معلبات',
      slug: 'canned',
      position: 6,
    ),
  ];

  static List<HomeProduct> _homeProducts() => const [
    HomeProduct(
      id: 'p-1',
      numericId: 1,
      sku: 'OIL-001',
      type: 'simple',
      name: 'زيت دوار الشمس',
      urlKey: 'sunflower-oil',
      price: 23.50,
      specialPrice: 19.99,
      formattedPrice: '€23.50',
      formattedSpecialPrice: '€19.99',
      isSaleable: true,
      averageRating: 4.5,
      reviewCount: 32,
    ),
    HomeProduct(
      id: 'p-2',
      numericId: 2,
      sku: 'RICE-001',
      type: 'simple',
      name: 'أرز بسمتي 5 كغ',
      urlKey: 'basmati-rice',
      price: 18.75,
      formattedPrice: '€18.75',
      isSaleable: true,
      averageRating: 4.8,
      reviewCount: 54,
    ),
    HomeProduct(
      id: 'p-3',
      numericId: 3,
      sku: 'MILK-001',
      type: 'simple',
      name: 'حليب كامل الدسم',
      urlKey: 'full-fat-milk',
      price: 12.30,
      specialPrice: 9.90,
      formattedPrice: '€12.30',
      formattedSpecialPrice: '€9.90',
      isSaleable: true,
      averageRating: 4.2,
      reviewCount: 21,
    ),
    HomeProduct(
      id: 'p-4',
      numericId: 4,
      sku: 'SUGAR-001',
      type: 'simple',
      name: 'سكر أبيض 1 كغ',
      urlKey: 'white-sugar',
      price: 5.20,
      formattedPrice: '€5.20',
      isSaleable: true,
      averageRating: 4.0,
      reviewCount: 12,
    ),
    HomeProduct(
      id: 'p-5',
      numericId: 5,
      sku: 'COFFEE-001',
      type: 'simple',
      name: 'قهوة عربية مطحونة',
      urlKey: 'arabic-coffee',
      price: 34.00,
      specialPrice: 28.50,
      formattedPrice: '€34.00',
      formattedSpecialPrice: '€28.50',
      isSaleable: true,
      averageRating: 4.9,
      reviewCount: 88,
    ),
    HomeProduct(
      id: 'p-6',
      numericId: 6,
      sku: 'HONEY-001',
      type: 'simple',
      name: 'عسل طبيعي 500 غ',
      urlKey: 'natural-honey',
      price: 45.00,
      formattedPrice: '€45.00',
      isSaleable: true,
      averageRating: 4.7,
      reviewCount: 41,
    ),
  ];

  /// One image-carousel (main banner) + two product-carousel customizations
  /// ("best sellers" + "new arrivals"), plus their products map, mirroring
  /// what the home builder expects.
  ///
  /// The image_carousel entry lets the main banner render while testing with
  /// preview data (the real banners come from the backend theme customization).
  static List<ThemeCustomization> homeCustomizations() => const [
    ThemeCustomization(
      id: 'tc-banner',
      type: 'image_carousel',
      name: 'البنر الرئيسي',
      status: true,
      sortOrder: 0,
      options: {
        'images': [
          {
            'image':
                'https://images.unsplash.com/photo-1542838132-92c53300491e?w=1200&q=80',
            'link': '',
            'title': 'عروض الخضار الطازجة',
          },
          {
            'image':
                'https://images.unsplash.com/photo-1506617420156-8e4536971650?w=1200&q=80',
            'link': '',
            'title': 'توصيل سريع لمنزلك',
          },
          {
            'image':
                'https://images.unsplash.com/photo-1550989460-0adf9ea622e2?w=1200&q=80',
            'link': '',
            'title': 'منتجات غذائية بأفضل الأسعار',
          },
        ],
      },
    ),
    ThemeCustomization(
      id: 'tc-best',
      type: 'product_carousel',
      name: 'المنتجات الأكثر مبيعاً',
      status: true,
      sortOrder: 1,
      options: {'title': 'المنتجات الأكثر مبيعاً'},
    ),
    ThemeCustomization(
      id: 'tc-new',
      type: 'product_carousel',
      name: 'المنتجات الجديدة',
      status: true,
      sortOrder: 2,
      options: {'title': 'المنتجات الجديدة'},
    ),
    ThemeCustomization(
      id: 'tc-offers',
      type: 'product_carousel',
      name: 'العروض الخاصة',
      status: true,
      sortOrder: 3,
      options: {'title': 'العروض الخاصة'},
    ),
    ThemeCustomization(
      id: 'tc-suggested',
      type: 'product_carousel',
      name: 'المنتجات المقترحة',
      status: true,
      sortOrder: 4,
      options: {'title': 'المنتجات المقترحة'},
    ),
  ];

  static Map<String, List<HomeProduct>> homeProductSections() => {
    'tc-best': _homeProducts(),
    'tc-new': _homeProducts().reversed.toList(),
    'tc-offers': _homeProducts().where((p) => p.specialPrice != null).toList().isNotEmpty
        ? _homeProducts().where((p) => p.specialPrice != null).toList()
        : _homeProducts(),
    'tc-suggested': _homeProducts(),
  };

  // ──────────────────────────────────────────────────────────────────────
  // CATEGORY SCREEN MOCK DATA
  // ──────────────────────────────────────────────────────────────────────

  static List<CategoryModel> categories() => const [
    CategoryModel(
      id: 'c-1',
      numericId: 1,
      position: 1,
      translation: CategoryTranslation(
        id: 't1',
        name: 'فواكه وخضار',
        slug: 'fruits-veg',
      ),
    ),
    CategoryModel(
      id: 'c-2',
      numericId: 2,
      position: 2,
      translation: CategoryTranslation(
        id: 't2',
        name: 'ألبان وأجبان',
        slug: 'dairy',
      ),
    ),
    CategoryModel(
      id: 'c-3',
      numericId: 3,
      position: 3,
      translation: CategoryTranslation(
        id: 't3',
        name: 'مخبوزات',
        slug: 'bakery',
      ),
    ),
    CategoryModel(
      id: 'c-4',
      numericId: 4,
      position: 4,
      translation: CategoryTranslation(
        id: 't4',
        name: 'مشروبات',
        slug: 'drinks',
      ),
    ),
    CategoryModel(
      id: 'c-5',
      numericId: 5,
      position: 5,
      translation: CategoryTranslation(
        id: 't5',
        name: 'وجبات خفيفة',
        slug: 'snacks',
      ),
    ),
  ];

  static CategoryModel selectedCategory() => categories().first;

  static List<ProductModel> products() => const [
    ProductModel(
      id: 'pm-1',
      numericId: 1,
      sku: 'OIL-001',
      type: 'simple',
      name: 'زيت دوار الشمس',
      urlKey: 'sunflower-oil',
      price: 23.50,
      formattedPrice: '€23.50',
      specialPrice: 19.99,
      formattedSpecialPrice: '€19.99',
      isSaleable: true,
      brand: 'الشمس',
    ),
    ProductModel(
      id: 'pm-2',
      numericId: 2,
      sku: 'RICE-001',
      type: 'simple',
      name: 'أرز بسمتي 5 كغ',
      urlKey: 'basmati-rice',
      price: 18.75,
      formattedPrice: '€18.75',
      isSaleable: true,
      brand: 'الواحة',
    ),
    ProductModel(
      id: 'pm-3',
      numericId: 3,
      sku: 'MILK-001',
      type: 'simple',
      name: 'حليب كامل الدسم',
      urlKey: 'full-fat-milk',
      price: 12.30,
      formattedPrice: '€12.30',
      specialPrice: 9.90,
      formattedSpecialPrice: '€9.90',
      isSaleable: true,
      brand: 'المراعي',
    ),
    ProductModel(
      id: 'pm-4',
      numericId: 4,
      sku: 'SUGAR-001',
      type: 'simple',
      name: 'سكر أبيض 1 كغ',
      urlKey: 'white-sugar',
      price: 5.20,
      formattedPrice: '€5.20',
      isSaleable: true,
      brand: 'النخيل',
    ),
    ProductModel(
      id: 'pm-5',
      numericId: 5,
      sku: 'COFFEE-001',
      type: 'simple',
      name: 'قهوة عربية مطحونة',
      urlKey: 'arabic-coffee',
      price: 34.00,
      formattedPrice: '€34.00',
      specialPrice: 28.50,
      formattedSpecialPrice: '€28.50',
      isSaleable: true,
      brand: 'بن العميد',
    ),
    ProductModel(
      id: 'pm-6',
      numericId: 6,
      sku: 'HONEY-001',
      type: 'simple',
      name: 'عسل طبيعي 500 غ',
      urlKey: 'natural-honey',
      price: 45.00,
      formattedPrice: '€45.00',
      isSaleable: true,
      brand: 'المنحل',
    ),
  ];

  // ──────────────────────────────────────────────────────────────────────
  // PRODUCT DETAIL MOCK DATA
  // ──────────────────────────────────────────────────────────────────────

  /// A single, richer product used by the product-detail preview.
  static ProductModel productDetail() => const ProductModel(
    id: 'pm-detail-1',
    numericId: 1,
    sku: 'OIL-001',
    type: 'simple',
    name: 'زيت دوار الشمس النقي 1 لتر',
    urlKey: 'sunflower-oil',
    description:
        'زيت دوار شمس نقي 100%، مثالي للقلي والطبخ والسلطات. غني بفيتامين E '
        'وخالٍ من الكوليسترول. معبأ بعناية للحفاظ على الجودة والنكهة.',
    shortDescription: 'زيت دوار شمس نقي 100% — صحي ومتعدد الاستخدامات.',
    price: 23.50,
    formattedPrice: '€23.50',
    specialPrice: 19.99,
    formattedSpecialPrice: '€19.99',
    isSaleable: true,
    brand: 'الشمس',
    weightValue: '1 لتر',
    qty: 120,
  );

  /// A few related products for the bottom carousel of the detail screen.
  static List<ProductModel> relatedProducts() => products().take(4).toList();

  // ──────────────────────────────────────────────────────────────────────
  // ADDRESS BOOK MOCK DATA
  // ──────────────────────────────────────────────────────────────────────

  static List<CustomerAddress> addresses() => const [
    CustomerAddress(
      id: 'a-1',
      numericId: 1,
      firstName: 'أحمد',
      lastName: 'محمد',
      address: 'شارع الأمير، مبنى 12، شقة 4',
      city: 'برلين',
      state: 'برلين',
      country: 'ألمانيا',
      zipCode: '10115',
      phone: '+49 163 1234567',
      isDefault: true,
      useForShipping: true,
    ),
    CustomerAddress(
      id: 'a-2',
      numericId: 2,
      firstName: 'أحمد',
      lastName: 'محمد',
      address: 'شارع السوق، مبنى 8',
      city: 'ميونخ',
      state: 'بافاريا',
      country: 'ألمانيا',
      zipCode: '80331',
      phone: '+49 170 7654321',
      isDefault: false,
    ),
  ];

  // ──────────────────────────────────────────────────────────────────────
  // WISHLIST MOCK DATA
  // ──────────────────────────────────────────────────────────────────────

  static List<WishlistItem> wishlistItems() => [
    WishlistItem(
      id: 'w-1',
      numericId: 1,
      productNumericId: 1,
      name: 'زيت دوار الشمس النقي 1 لتر',
      sku: 'OIL-001',
      type: 'simple',
      price: 23.50,
      specialPrice: 19.99,
      apiFormattedPrice: '€23.50',
      apiFormattedSpecialPrice: '€19.99',
      urlKey: 'sunflower-oil',
    ),
    WishlistItem(
      id: 'w-2',
      numericId: 2,
      productNumericId: 5,
      name: 'قهوة عربية مطحونة',
      sku: 'COFFEE-001',
      type: 'simple',
      price: 34.00,
      specialPrice: 28.50,
      apiFormattedPrice: '€34.00',
      apiFormattedSpecialPrice: '€28.50',
      urlKey: 'arabic-coffee',
    ),
    WishlistItem(
      id: 'w-3',
      numericId: 3,
      productNumericId: 6,
      name: 'عسل طبيعي 500 غ',
      sku: 'HONEY-001',
      type: 'simple',
      price: 45.00,
      apiFormattedPrice: '€45.00',
      urlKey: 'natural-honey',
    ),
  ];

  // ──────────────────────────────────────────────────────────────────────
  // ORDERS MOCK DATA
  // ──────────────────────────────────────────────────────────────────────

  static List<CustomerOrder> orders() => const [
    CustomerOrder(
      id: 'o-1',
      numericId: 1258,
      incrementId: '1258',
      status: 'completed',
      totalItemCount: 4,
      totalQtyOrdered: 4,
      grandTotal: 1250.00,
      subTotal: 1180.00,
      createdAt: '2026-06-25 10:30:00',
    ),
    CustomerOrder(
      id: 'o-2',
      numericId: 1257,
      incrementId: '1257',
      status: 'processing',
      totalItemCount: 2,
      totalQtyOrdered: 3,
      grandTotal: 850.00,
      subTotal: 820.00,
      createdAt: '2026-06-24 09:15:00',
    ),
    CustomerOrder(
      id: 'o-3',
      numericId: 1256,
      incrementId: '1256',
      status: 'pending',
      totalItemCount: 1,
      totalQtyOrdered: 1,
      grandTotal: 560.00,
      subTotal: 540.00,
      createdAt: '2026-06-23 18:45:00',
    ),
    CustomerOrder(
      id: 'o-4',
      numericId: 1255,
      incrementId: '1255',
      status: 'canceled',
      totalItemCount: 3,
      totalQtyOrdered: 5,
      grandTotal: 980.00,
      subTotal: 940.00,
      createdAt: '2026-06-22 14:05:00',
    ),
    CustomerOrder(
      id: 'o-5',
      numericId: 1254,
      incrementId: '1254',
      status: 'closed',
      totalItemCount: 2,
      totalQtyOrdered: 2,
      grandTotal: 430.00,
      subTotal: 410.00,
      createdAt: '2026-06-20 11:20:00',
    ),
  ];

  /// Rich OrderDetail mock for the order-detail screen. `status` and
  /// `incrementId` can be passed so the opened order matches the tapped one.
  static OrderDetail orderDetail({
    String status = 'processing',
    String incrementId = '1257',
  }) {
    return OrderDetail(
      id: 'od-1',
      numericId: int.tryParse(incrementId),
      incrementId: incrementId,
      status: status,
      customerFirstName: 'أحمد',
      customerLastName: 'محمد',
      customerEmail: 'ahmad@example.com',
      totalItemCount: 3,
      totalQtyOrdered: 3,
      grandTotal: 850.00,
      subTotal: 790.00,
      taxAmount: 40.00,
      shippingAmount: 20.00,
      shippingTitle: 'التوصيل القياسي',
      orderCurrencyCode: 'EUR',
      createdAt: '2026-06-24 09:15:00',
      items: const [
        OrderItem(
          name: 'زيت دوار الشمس النقي 1 لتر',
          sku: 'OIL-001',
          qtyOrdered: 2,
          price: 23.50,
          total: 47.00,
        ),
        OrderItem(
          name: 'أرز بسمتي 5 كغ',
          sku: 'RICE-001',
          qtyOrdered: 1,
          price: 18.75,
          total: 18.75,
        ),
        OrderItem(
          name: 'قهوة عربية مطحونة',
          sku: 'COFFEE-001',
          qtyOrdered: 1,
          price: 28.50,
          total: 28.50,
        ),
      ],
      shippingAddress: const OrderAddress(
        firstName: 'أحمد',
        lastName: 'محمد',
        address: 'شارع الأمير، مبنى 12، شقة 4',
        city: 'برلين',
        country: 'ألمانيا',
        postcode: '10115',
        phone: '+49 163 1234567',
      ),
      billingAddress: const OrderAddress(
        firstName: 'أحمد',
        lastName: 'محمد',
        address: 'شارع الأمير، مبنى 12، شقة 4',
        city: 'برلين',
        country: 'ألمانيا',
        postcode: '10115',
        phone: '+49 163 1234567',
      ),
      payment: const OrderPayment(
        method: 'cashondelivery',
        methodTitle: 'الدفع عند الاستلام',
      ),
    );
  }
}

/// ── PREVIEW LAUNCHER ──
/// A small panel (only shown when kUsePreviewData) that lets you jump straight
/// into screens you normally can't reach without a backend (e.g. the Thank-You
/// screen, which only appears after a real order).
///
/// To remove: delete this widget and the single place it is used (search for
/// `PreviewLauncher(`). It is wrapped in `if (kUsePreviewData)` so it never
/// appears in production once the switch is off.
class PreviewLauncher extends StatelessWidget {
  const PreviewLauncher({
    super.key,
    required this.onOpenThankYou,
    this.onOpenOrders,
    this.onOpenAddresses,
    this.onOpenWishlist,
  });

  /// Called when the user taps "Thank-You screen".
  final VoidCallback onOpenThankYou;

  /// Optional: called when the user taps "Orders screen".
  final VoidCallback? onOpenOrders;

  /// Optional: called when the user taps "Addresses screen".
  final VoidCallback? onOpenAddresses;

  /// Optional: called when the user taps "Wishlist screen".
  final VoidCallback? onOpenWishlist;

  @override
  Widget build(BuildContext context) {
    if (!kUsePreviewData) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SentryPalette.softViolet.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: SentryPalette.softViolet.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.visibility_outlined,
                size: 18,
                color: SentryPalette.violet,
              ),
              const SizedBox(width: 6),
              Text(
                'وضع المعاينة (preview)',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: SentryPalette.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'أزرار مؤقتة لمعاينة الشاشات التي تحتاج باك إند. تختفي عند جعل kUsePreviewData = false.',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 11,
              height: 1.4,
              color: SentryPalette.ink.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onOpenThankYou,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: SentryPalette.brandGradient,
                borderRadius: BorderRadius.circular(40),
              ),
              child: const Text(
                'معاينة شاشة الشكر',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          if (onOpenOrders != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onOpenOrders,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: SentryPalette.violet, width: 1.5),
                ),
                child: Text(
                  'معاينة شاشة الطلبات',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: SentryPalette.violet,
                  ),
                ),
              ),
            ),
          ],
          if (onOpenAddresses != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onOpenAddresses,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: SentryPalette.violet, width: 1.5),
                ),
                child: Text(
                  'معاينة العناوين',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: SentryPalette.violet,
                  ),
                ),
              ),
            ),
          ],
          if (onOpenWishlist != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onOpenWishlist,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: SentryPalette.violet, width: 1.5),
                ),
                child: Text(
                  'معاينة المفضلة',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: SentryPalette.violet,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
