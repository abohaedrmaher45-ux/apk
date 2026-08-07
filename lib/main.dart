import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'l10n/app_localizations.dart';
import 'core/channel/channel_bootstrap_service.dart';
import 'core/constants/api_config.dart';
import 'core/graphql/graphql_client.dart';
import 'core/currency/currency_cubit.dart';
import 'core/currency/currency_formatter.dart';
import 'core/locale/locale_cubit.dart';
import 'core/navigation/route_observer.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_cubit.dart';
import 'core/wishlist/wishlist_cubit.dart';
import 'core/notifications/firebase_service.dart';
import 'core/notifications/fcm_service.dart';
import 'core/error/error_mapper.dart';
import 'core/widgets/app_update_gate.dart';
import 'features/auth/data/repository/auth_repository.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/category/presentation/pages/category_products_grid_page.dart';
import 'features/product/presentation/pages/product_detail_page.dart';
import 'features/account/presentation/pages/order_detail_page.dart';
import 'features/account/data/repository/account_repository.dart';
import 'features/category/data/repository/category_repository.dart';
import 'features/category/presentation/bloc/category_bloc.dart';
import 'features/cart/data/repository/cart_repository.dart';
import 'features/cart/presentation/bloc/cart_bloc.dart';
import 'features/home/data/repository/home_repository.dart';
import 'features/home/presentation/bloc/home_bloc.dart';
import 'features/home/presentation/pages/main_shell.dart';
import 'features/splash/presentation/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── التهيئة الدنيا الضرورية فقط قبل عرض الواجهة ──
  // نحتاج SharedPreferences + ApiConfig لأن BagistoApp يعتمد عليهما مباشرة.
  // نبقي هذا خفيفًا جدًا حتى تظهر شاشة splash.png فورًا بدل لوغو أندرويد.
  await initHiveForFlutter().catchError((e) {
    debugPrint('Hive init failed (using in-memory cache): $e');
  });

  final prefs = await SharedPreferences.getInstance();
  await ApiConfig.load(prefs);
  CurrencyFormatter.initialize(prefs);

  // اعرض التطبيق فورًا — تظهر صورة الـ splash الآن وتبقى طوال التحميل.
  runApp(BagistoApp(prefs: prefs));

  // ── التهيئة الثقيلة تجري في الخلفية بعد ظهور الواجهة ──
  // (Firebase, FCM, Channel bootstrap) لا تؤخّر ظهور الشاشة بعد الآن.
  _initInBackground(prefs);
}

/// تهيئة ثقيلة (شبكة/إشعارات) تُنفَّذ بعد runApp حتى لا تؤخّر ظهور الـ splash.
Future<void> _initInBackground(SharedPreferences prefs) async {
  final firebaseEnabled = await FirebaseService.initialize();

  if (firebaseEnabled) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } else {
    debugPrint(
      '⚠️ Firebase is disabled. App will continue without push notifications.',
    );
  }

  try {
    await ChannelBootstrapService(
      client: GraphQLClientProvider.buildClient(),
      prefs: prefs,
    ).bootstrap();
  } catch (e) {
    debugPrint('Channel bootstrap error: $e');
  }

  if (firebaseEnabled) {
    try {
      await FCMService().initialize(
        onForegroundMessage: _handleForegroundNotification,
        onBackgroundMessage: _handleBackgroundNotification,
        onMessageOpenedApp: _handleMessageOpenedApp,
        onLocalNotificationTapped: _handleLocalNotificationTapped,
      );

      debugPrint('⏳ Retrieving device token from FCMService...');
      try {
        final deviceToken = await FCMService().getDeviceToken();
        if (deviceToken != null && deviceToken.isNotEmpty) {
          debugPrint('✅ FCM device token is available');
        } else {
          debugPrint(
            '⚠️ Token not yet available, FCMService will retry automatically',
          );
        }
      } catch (e) {
        debugPrint('⚠️ Token retrieval note: $e');
      }
    } catch (e) {
      debugPrint('FCM initialization error: $e');
    }
  } else {
    debugPrint('⚠️ Skipping FCM initialization because Firebase is disabled.');
  }
}

/// Handle notification when app is in foreground
Future<void> _handleForegroundNotification(RemoteMessage message) async {
  debugPrint(
    '📬 Foreground notification handler called '
    '(id=${message.messageId}, hasData=${message.data.isNotEmpty})',
  );

  // Handle navigation based on notification type
  // REMOVED: _navigateFromNotification(message);
  // Navigation should only happen when the user taps the local notification,
  // which is handled by _handleLocalNotificationTapped.
}

/// Handle notification when app is in background
/// Note: Background handler must be a top-level function
Future<void> _handleBackgroundNotification(RemoteMessage message) async {
  debugPrint('🌙 Background notification received');
  // Background handler is already implemented in FCMService
}

/// Handle notification when app is opened from background
Future<void> _handleMessageOpenedApp(RemoteMessage message) async {
  debugPrint('📲 App opened from notification: ${message.messageId}');

  // Handle navigation based on notification type
  _navigateFromNotificationData(message.data);
}

/// Handle local notification tap (when app is in foreground and user taps notification)
Future<void> _handleLocalNotificationTapped(Map<String, dynamic> data) async {
  debugPrint(
    '📲 Local notification tapped '
    '(keys=${data.keys.join(',')})',
  );

  // Navigate based on notification data
  _navigateFromNotificationData(data);
}

/// Extract a numeric ID from a string that may be a pure number,
/// an IRI path like "/api/shop/customer-orders/577", or URL-encoded.
int? _extractNumericId(String? raw) {
  if (raw == null || raw.isEmpty) return null;

  // Decode any percent-encoding first (e.g. %2F → /)
  final decoded = Uri.decodeComponent(raw);

  // If it's already a pure number, use it directly
  final direct = int.tryParse(decoded);
  if (direct != null) return direct;

  // Try to extract the last numeric segment from a path
  // e.g. "/api/shop/customer-orders/577" → "577"
  final segments = decoded.split('/').where((s) => s.isNotEmpty).toList();
  for (var i = segments.length - 1; i >= 0; i--) {
    final n = int.tryParse(segments[i]);
    if (n != null) return n;
  }

  return null;
}

/// Navigate based on a notification's `data` payload — shared by the local
/// tap handler (foreground) and `onMessageOpenedApp`/initial-message
/// handlers (background/terminated); both ultimately carry the same `data`
/// map, just reached via different Firebase code paths.
///
/// Supports the legacy custom types (`category`, `product` with camelCase
/// fields) alongside the backend's current push-notification types from the
/// FCM integration doc §4 — `order_status`, `new_product`, `discount`,
/// `offer`, `admin_message` — which use snake_case fields (`order_id`,
/// `product_id`, `rule_id`, `rule_type`).
Future<void> _navigateFromNotificationData(Map<String, dynamic> data) async {
  try {
    // 'type' is the doc's field; 'notificationType' is the legacy one.
    var type = data['type']?.toString().toLowerCase();
    type ??= data['notificationType']?.toString().toLowerCase();

    debugPrint('🔗 Notification type: $type');

    final mainShellContext = MainShell.navigatorKey.currentContext;
    if (mainShellContext == null) {
      debugPrint('⚠️ MainShell context not available yet, will retry');
      Future.delayed(const Duration(seconds: 1), () {
        _navigateFromNotificationData(data);
      });
      return;
    }

    switch (type) {
      case 'category':
        _navigateToCategory(mainShellContext, data);
        break;

      case 'product':
        await _navigateToProduct(mainShellContext, data);
        break;

      case 'new_product':
        // منتج جديد (البند 4 من مستند التكامل) → صفحة المنتج عبر product_id.
        final productId =
            data['product_id']?.toString() ?? data['productId']?.toString();
        if (productId == null || productId.isEmpty) {
          debugPrint('⚠️ Missing product_id in new_product notification');
          break;
        }
        await _navigateToProductById(mainShellContext, productId);
        break;

      case 'order':
      case 'order_status':
        _navigateToOrder(mainShellContext, data);
        break;

      case 'discount':
        // rule_id / rule_type (cart_rule | catalog_rule) — لا توجد صفحة
        // كوبونات مستقلة بعد؛ أقرب وجهة متاحة هي الرئيسية (قسم العروض).
        debugPrint(
          '🏷️ Discount notification — rule_id=${data['rule_id']}, '
          'rule_type=${data['rule_type']}. Navigating to Home.',
        );
        _navigateToHome(mainShellContext);
        break;

      case 'offer':
        _navigateToHome(mainShellContext);
        break;

      case 'admin_message':
        // "عرض الرسالة فقط، بلا تنقّل خاص" — الرسالة ظهرت أصلاً كإشعار نظام
        // عند وصولها؛ لا حاجة لأي تنقّل عند الضغط عليها.
        debugPrint('💬 Admin message notification tapped — no navigation.');
        break;

      default:
        debugPrint('ℹ️ Unknown notification type: $type');
    }
  } catch (e) {
    debugPrint('❌ Error navigating from notification: $e');
  }
}

void _navigateToCategory(BuildContext context, Map<String, dynamic> data) {
  final categoryId = int.tryParse(
    data['categoryId']?.toString() ?? data['category_id']?.toString() ?? '',
  );
  final categoryName = data['categoryName']?.toString() ?? 'Products';
  final categorySlug = data['categorySlug']?.toString() ?? '';

  if (categoryId == null) {
    debugPrint('⚠️ Missing categoryId in notification data');
    return;
  }

  debugPrint('📂 Navigating to category: $categoryName (ID: $categoryId)');
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => CategoryProductsGridPage(
        categoryId: categoryId,
        categoryName: categoryName,
        categorySlug: categorySlug,
      ),
    ),
  );
}

/// Navigate to product detail (supports both URL key and product ID).
Future<void> _navigateToProduct(
  BuildContext context,
  Map<String, dynamic> data,
) async {
  final productUrlKey = data['productUrlKey']?.toString();
  final productName = data['productName']?.toString();
  final productType = data['productType']?.toString();

  if (productUrlKey != null && productUrlKey.isNotEmpty) {
    debugPrint(
      '🛍️ Navigating to product: $productName (URL key: $productUrlKey)',
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailPage(
          urlKey: productUrlKey,
          productName: productName,
          productType: productType,
        ),
      ),
    );
    return;
  }

  final productId =
      data['productId']?.toString() ?? data['product_id']?.toString();
  if (productId != null && productId.isNotEmpty) {
    await _navigateToProductById(context, productId);
    return;
  }

  debugPrint('⚠️ Missing productUrlKey or productId in notification data');
}

/// Fetches a product by numeric ID then pushes its detail page. Shared by
/// the legacy `product` type and the new `new_product` type.
Future<void> _navigateToProductById(
  BuildContext context,
  String productId,
) async {
  debugPrint('🛍️ Fetching product details for ID: $productId');
  try {
    final navigator = Navigator.of(context);
    final repository = context.read<CategoryRepository>();
    final product = await repository.getProductById(productId);

    if (product.urlKey == null || product.urlKey!.isEmpty) {
      debugPrint('⚠️ Product does not have URL key');
      return;
    }

    debugPrint(
      '✅ Product fetched: ${product.name} (URL key: ${product.urlKey})',
    );
    navigator.push(
      MaterialPageRoute(
        builder: (_) => ProductDetailPage(
          urlKey: product.urlKey!,
          productName: product.name,
          productType: product.type,
        ),
      ),
    );
  } catch (e) {
    debugPrint('❌ Failed to fetch product by ID: $e');
  }
}

void _navigateToOrder(BuildContext context, Map<String, dynamic> data) {
  // The notification may send: order_id=576 (doc), orderId=576 (legacy),
  // id=576, or the full IRI=/api/shop/customer-orders/576.
  final orderId = _extractNumericId(
    data['order_id']?.toString() ??
        data['orderId']?.toString() ??
        data['id']?.toString(),
  );
  final orderNumber = data['orderNumber'] ?? data['order_number'];

  debugPrint(
    '📦 Order notification data: orderId=$orderId, orderNumber=$orderNumber, '
    'status=${data['status']}',
  );

  if (orderId == null) {
    debugPrint('⚠️ Missing or invalid order id in notification data');
    return;
  }

  debugPrint('📦 Navigating to order: #$orderNumber (ID: $orderId)');

  // Get AccountRepository from context (similar to how orders_page does it)
  AccountRepository? repository;
  try {
    repository = RepositoryProvider.of<AccountRepository>(context);
  } catch (e) {
    debugPrint('⚠️ Could not get repository from context, trying read...');
    try {
      repository = context.read<AccountRepository>();
    } catch (e2) {
      // Repository not in context — create one with an authenticated client.
      // Order endpoints require auth; using the guest client causes 500 errors.
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated) {
        final authClient = GraphQLClientProvider.authenticatedClient(
          authState.token,
        );
        repository = AccountRepository(client: authClient.value);
      } else {
        debugPrint('⚠️ User not authenticated — cannot view order');
        return;
      }
    }
  }

  OrderDetailPage.navigate(
    context,
    orderId: orderId,
    orderNumber: orderNumber?.toString(),
    repository: repository,
  );
}

/// Pops back to the root route and switches the bottom nav to the Home tab
/// — used for notification types with no dedicated destination page yet
/// (`offer`, `discount`).
void _navigateToHome(BuildContext context) {
  Navigator.of(context).popUntil((route) => route.isFirst);
  MainShell.navigatorKey.currentState?.switchToTab(0);
}

/// Send test notification (for debugging)
Future<void> _sendTestNotification() async {
  try {
    // Create a mock RemoteMessage for testing
    debugPrint(
      '✅ Test notification system ready! Token subscribed to bagisto_mobikul topic',
    );
    debugPrint('📢 Send notifications from Firebase Console with data:');
    debugPrint('   1. FOR CATEGORY PRODUCTS:');
    debugPrint('      - notificationType: category');
    debugPrint('      - categoryId: <category_id>');
    debugPrint('      - categoryName: <category_name>');
    debugPrint('      - categorySlug: <optional_slug>');
    debugPrint('   2. FOR PRODUCT DETAIL (by URL key):');
    debugPrint('      - notificationType: product');
    debugPrint('      - productUrlKey: <product_url_key>');
    debugPrint('      - productName: <product_name>');
    debugPrint('   3. FOR PRODUCT DETAIL (by ID):');
    debugPrint('      - notificationType: product');
    debugPrint('      - productId: <product_id>');
    debugPrint('      - productName: <product_name> (optional)');
    debugPrint('   4. FOR ORDER DETAIL:');
    debugPrint('      - notificationType: order OR type: order_status');
    debugPrint('      - orderId: <order_id>');
    debugPrint('      - orderNumber: <order_number> (optional)');
  } catch (e) {
    debugPrint('❌ Test notification error: $e');
  }
}

class BagistoApp extends StatelessWidget {
  final SharedPreferences prefs;

  const BagistoApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    final clientNotifier = GraphQLClientProvider.client;

    return GraphQLProvider(
      client: clientNotifier,
      child: MultiRepositoryProvider(
        providers: [
          RepositoryProvider<CategoryRepository>(
            create: (_) => CategoryRepository(client: clientNotifier.value),
          ),
          RepositoryProvider<CartRepository>(
            create: (_) => CartRepository(client: clientNotifier.value),
          ),
          RepositoryProvider<AuthRepository>(
            create: (_) => AuthRepository(client: clientNotifier.value),
          ),
          RepositoryProvider<HomeRepository>(
            create: (_) => HomeRepository(client: clientNotifier.value),
          ),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => ThemeCubit()..initialize(prefs)),
            BlocProvider(create: (_) => CurrencyCubit()..initialize(prefs)),
            BlocProvider(create: (_) => LocaleCubit()..initialize(prefs)),
            BlocProvider(
              create: (ctx) =>
                  AuthBloc(repository: ctx.read<AuthRepository>())
                    ..add(const AuthCheckStatus()),
            ),
            BlocProvider(
              create: (ctx) =>
                  CategoryBloc(repository: ctx.read<CategoryRepository>())
                    ..add(LoadCategories()),
            ),
            BlocProvider(
              create: (ctx) =>
                  CartBloc(repository: ctx.read<CartRepository>())
                    ..add(LoadCart()),
            ),
            BlocProvider(
              create: (ctx) =>
                  HomeBloc(repository: ctx.read<HomeRepository>())
                    ..add(const LoadHome()),
            ),
            BlocProvider(create: (_) => WishlistCubit()..loadWishlist()),
          ],
          child: const _AppWithAuthCartSync(),
        ),
      ),
    );
  }
}

/// Widget that listens to AuthBloc state changes and synchronizes the CartBloc.
///
/// This is the Flutter equivalent of the Next.js SessionSync + useMergeCart:
///
///  • On login  → fires [OnUserLoggedIn] which switches the cart bearer token
///    to the auth access token and merges the guest cart into the user's cart.
///
///  • On logout → fires [OnUserLoggedOut] which resets cart state and
///    creates a fresh guest cart session.
class _AppWithAuthCartSync extends StatefulWidget {
  const _AppWithAuthCartSync();

  @override
  State<_AppWithAuthCartSync> createState() => _AppWithAuthCartSyncState();
}

class _AppWithAuthCartSyncState extends State<_AppWithAuthCartSync> {
  /// Track previous auth state to detect transitions (login / logout).
  bool _wasAuthenticated = false;
  String? _lastAuthToken;
  bool _initialAuthCheckDone = false;
  bool _logoutSyncTriggered = false;

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, authState) {
        final cartBloc = context.read<CartBloc>();

        // On first auth state, sync the cart if user is already authenticated
        if (!_initialAuthCheckDone) {
          _initialAuthCheckDone = true;
          if (authState is AuthAuthenticated) {
            _wasAuthenticated = true;
            _lastAuthToken = authState.token;
            debugPrint(
              '🔄 Auth→Cart sync: user already logged in — firing OnUserLoggedIn',
            );
            cartBloc.add(OnUserLoggedIn(authToken: authState.token));
            context.read<WishlistCubit>().loadWishlist();
            return;
          }
        }

        if (authState is AuthAuthenticated) {
          // User just logged in — sync the cart
          if (!_wasAuthenticated || _lastAuthToken != authState.token) {
            debugPrint(
              '🔄 Auth→Cart sync: user logged in — firing OnUserLoggedIn',
            );
            cartBloc.add(OnUserLoggedIn(authToken: authState.token));
            context.read<WishlistCubit>().loadWishlist();
            _wasAuthenticated = true;
            _lastAuthToken = authState.token;
            _logoutSyncTriggered = false;
          }
        } else if (authState is AuthLoading) {
          // Logout flow enters loading while token is still available.
          // Trigger cart reset here so we can clear user cart data promptly.
          if (_wasAuthenticated && !_logoutSyncTriggered) {
            debugPrint(
              '🔄 Auth→Cart sync: auth loading after login — firing OnUserLoggedOut',
            );
            cartBloc.add(const OnUserLoggedOut());
            context.read<WishlistCubit>().clearWishlist();
            _logoutSyncTriggered = true;
          }
        } else if (authState is AuthUnauthenticated) {
          // User just logged out — reset the cart
          if (_wasAuthenticated && !_logoutSyncTriggered) {
            debugPrint(
              '🔄 Auth→Cart sync: user logged out — firing OnUserLoggedOut',
            );
            cartBloc.add(const OnUserLoggedOut());
            context.read<WishlistCubit>().clearWishlist();
          }
          _wasAuthenticated = false;
          _lastAuthToken = null;
          _logoutSyncTriggered = false;
        }
      },
      child: MultiBlocListener(
        listeners: [
          BlocListener<LocaleCubit, Locale?>(
            listenWhen: (previous, current) =>
                current != null &&
                previous?.languageCode != current.languageCode,
            listener: (context, state) async {
              final homeBloc = context.read<HomeBloc>();
              final categoryBloc = context.read<CategoryBloc>();
              final cartBloc = context.read<CartBloc>();
              await GraphQLClientProvider.clearCache();
              homeBloc.add(const RefreshHome());
              categoryBloc.add(LoadCategories());
              cartBloc.add(LoadCart());
            },
          ),
          BlocListener<CurrencyCubit, String?>(
            listenWhen: (previous, current) =>
                current != null && previous != current,
            listener: (context, state) async {
              final homeBloc = context.read<HomeBloc>();
              final categoryBloc = context.read<CategoryBloc>();
              final cartBloc = context.read<CartBloc>();
              await GraphQLClientProvider.clearCache();
              homeBloc.add(const RefreshHome());
              categoryBloc.add(LoadCategories());
              cartBloc.add(LoadCart());
            },
          ),
        ],
        child: BlocBuilder<ThemeCubit, ThemeMode>(
          builder: (context, themeMode) => BlocBuilder<LocaleCubit, Locale?>(
            builder: (context, locale) {
              ErrorMapper.updateLocale(locale);
              return MaterialApp(
                onGenerateTitle: (context) =>
                    AppLocalizations.of(context)!.appTitle,
                debugShowCheckedModeBanner: false,
                navigatorObservers: [appRouteObserver],
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: themeMode,
                locale: locale,
                localizationsDelegates: [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: AppLocalizations.supportedLocales,
                home: SplashScreen(
                  nextScreen: AppUpdateGate(
                    child: MainShell(key: MainShell.navigatorKey),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
