import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/currency/currency_cubit.dart';
import '../../../../core/graphql/graphql_client.dart';
import '../../../../core/locale/locale_cubit.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sentry_ui.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../account/data/repository/account_repository.dart';
import '../../../account/presentation/bloc/account_dashboard_bloc.dart';
import '../../../account/presentation/pages/account_dashboard_page.dart';
import '../../../account/presentation/pages/preferences_bottom_sheet.dart';
import '../bloc/auth_bloc.dart';
import 'login_page.dart';
import 'sign_up_page.dart';
import '../../../../core/dev/preview_data.dart'; // PREVIEW-ONLY
import '../../../checkout/presentation/pages/thankyou_page.dart'; // PREVIEW-ONLY
import '../../../account/presentation/pages/orders_page.dart'; // PREVIEW-ONLY
import '../../../account/presentation/bloc/orders_bloc.dart'; // PREVIEW-ONLY
import '../../../account/presentation/pages/address_book_page.dart'; // PREVIEW-ONLY
import '../../../account/presentation/bloc/address_book_bloc.dart'; // PREVIEW-ONLY
import '../../../account/presentation/pages/wishlist_page.dart'; // PREVIEW-ONLY
import '../../../account/presentation/bloc/wishlist_bloc.dart'; // PREVIEW-ONLY

/// Account page — shows login/signup when unauthenticated,
/// and the full account dashboard when authenticated.
/// Figma: node-id=206-8238 (account-without-login)
/// Figma: node-id=220-6313 (account-dashboard)
class AccountPage extends StatefulWidget {
  final bool isActive;
  const AccountPage({super.key, this.isActive = false});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  AccountDashboardBloc? _dashboardBloc;
  String? _currentToken;

  @override
  void didUpdateWidget(AccountPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When the tab becomes active, refresh data in the background
    if (widget.isActive && !oldWidget.isActive) {
      _dashboardBloc?.add(const RefreshAccountDashboard());
    }
  }

  @override
  void dispose() {
    _dashboardBloc?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<LocaleCubit, Locale?>(
          listenWhen: (previous, current) =>
              current != null && previous?.languageCode != current.languageCode,
          listener: (context, state) {
            _dashboardBloc?.add(const RefreshAccountDashboard());
          },
        ),
        BlocListener<CurrencyCubit, String?>(
          listenWhen: (previous, current) =>
              current != null && previous != current,
          listener: (context, state) {
            _dashboardBloc?.add(const RefreshAccountDashboard());
          },
        ),
      ],
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is AuthAuthenticated) {
            return _buildAuthenticatedDashboard(context, state);
          }
          // Clean up bloc when logged out
          _dashboardBloc?.close();
          _dashboardBloc = null;
          _currentToken = null;
          return const _LoggedOutView();
        },
      ),
    );
  }

  Widget _buildAuthenticatedDashboard(
    BuildContext context,
    AuthAuthenticated state,
  ) {
    // Only recreate bloc when token changes (avoids rebuilds)
    if (_currentToken != state.token || _dashboardBloc == null) {
      _dashboardBloc?.close();
      _currentToken = state.token;

      final authClient = GraphQLClientProvider.authenticatedClient(state.token);
      final repository = AccountRepository(client: authClient.value);
      _dashboardBloc = AccountDashboardBloc(
        repository: repository,
        customerId: state.userId,
      );
      // Defer loading to next frame - prevents API call on app startup
      // Will be triggered when user actually views the account tab
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _dashboardBloc?.add(const LoadAccountDashboard());
      });
    }

    return RepositoryProvider<AccountRepository>.value(
      value: _dashboardBloc!.repository,
      child: BlocProvider<AccountDashboardBloc>.value(
        value: _dashboardBloc!,
        child: const AccountDashboardPage(),
      ),
    );
  }
}

/// ─── LOGGED OUT VIEW ───
class _LoggedOutView extends StatelessWidget {
  const _LoggedOutView();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: SentryPalette.pageBackground(isDark),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: SentryBackground(variant: 3)),
          SafeArea(
            child: SentryPageEntrance(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            const SizedBox(height: 40),

                            // ── Bagisto Logo + Wordmark ──
                            _buildLogo(isDark),

                            const SizedBox(height: 32),

                            // ── "Nice to see you here" ──
                            Text(
                              l10n.authNiceToSeeYouHere,
                              style: AppTextStyles.text2(context).copyWith(
                                color: isDark
                                    ? Colors.white
                                    : SentryPalette.ink,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),

                            const SizedBox(height: 12),

                            // ── Sign Up & Login Buttons ──
                            _buildAuthButtons(context, isDark, l10n),

                            // PREVIEW-ONLY: temporary launcher for backend-gated
                            // screens (e.g. the Thank-You screen).
                            PreviewLauncher(
                              onOpenThankYou: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const ThankyouPage(
                                      orderIncrementId: '1258',
                                    ),
                                  ),
                                );
                              },
                              onOpenOrders: () {
                                final repository = AccountRepository(
                                  client: GraphQLClientProvider.client.value,
                                );
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => RepositoryProvider.value(
                                      value: repository,
                                      child: BlocProvider(
                                        create: (_) =>
                                            OrdersBloc(repository: repository),
                                        child: const OrdersPage(),
                                      ),
                                    ),
                                  ),
                                );
                              },
                              onOpenAddresses: () {
                                final repository = AccountRepository(
                                  client: GraphQLClientProvider.client.value,
                                );
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => RepositoryProvider.value(
                                      value: repository,
                                      child: BlocProvider(
                                        create: (_) => AddressBookBloc(
                                          repository: repository,
                                        ),
                                        child: const AddressBookPage(),
                                      ),
                                    ),
                                  ),
                                );
                              },
                              onOpenWishlist: () {
                                final repository = AccountRepository(
                                  client: GraphQLClientProvider.client.value,
                                );
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => RepositoryProvider.value(
                                      value: repository,
                                      child: BlocProvider(
                                        create: (_) => WishlistBloc(
                                          repository: repository,
                                        ),
                                        child: const WishlistPage(),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 36),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── Preferences Chip (bottom) ──
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildPreferencesChip(context, isDark, l10n),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Bagisto logo icon + "bagisto" wordmark
  Widget _buildLogo(bool isDark) {
    return Center(
      child: Container(
        height: 96,
        width: 96,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: SentryPalette.brandGradient,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: SentryPalette.violet.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SvgPicture.asset(
          'assets/images/bagisto_logo.svg',
          height: 60,
          width: 60,
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        ),
      ),
    );
  }

  /// Sign Up (primary) + Login (secondary) buttons
  Widget _buildAuthButtons(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: Row(
        children: [
          // Sign Up — Primary button
          Expanded(
            child: SentryGradientButton(
              height: 50,
              label: l10n.authSignUp,
              onPressed: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const SignUpPage()));
              },
            ),
          ),

          const SizedBox(width: 12),

          // Login — Secondary (outlined) button
          Expanded(
            child: SizedBox(
              height: 50,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const LoginPage()));
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: SentryPalette.violet,
                  side: BorderSide(
                    color: isDark
                        ? SentryPalette.softViolet.withValues(alpha: 0.4)
                        : SentryPalette.softViolet,
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(54),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    height: 1.17,
                  ),
                ),
                child: Text(l10n.authLogin),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Preferences chip at bottom
  /// Figma: list component — neutral/100 bg, 10px radius
  Widget _buildPreferencesChip(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
  ) {
    return GestureDetector(
      onTap: () =>
          PreferencesBottomSheet.show(context, showSettingsSection: true),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.neutral800 : AppColors.neutral100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tune_outlined,
              size: 24,
              color: isDark ? AppColors.neutral300 : AppColors.neutral900,
            ),
            const SizedBox(width: 4),
            Text(
              l10n.accountPreferences,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontWeight: FontWeight.w400,
                fontSize: 14,
                height: 1.17,
                color: isDark ? AppColors.neutral200 : AppColors.neutral900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
