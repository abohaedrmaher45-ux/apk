import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sentry_ui.dart';
import '../../../../l10n/app_localizations.dart';
import '../bloc/auth_bloc.dart';
import 'forgot_password_page.dart';
import 'sign_up_page.dart';
import '../../../../core/widgets/app_back_button.dart';

/// Login page for existing customers
/// Figma: authentication flow — login screen
///
/// Layout:
///   ─ AppBar with back arrow
///   ─ Bagisto logo + wordmark
///   ─ "Welcome back!" heading (Text-2)
///   ─ Email text field
///   ─ Password text field (with visibility toggle)
///   ─ "Forgot Password?" link
///   ─ [Login] primary button (full width)
///   ─ "Sign in with" + social icons
///   ─ "Don't have an account? Sign Up" link
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(
        AuthLoginRequested(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: SentryPalette.pageBackground(isDark),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(),
        actions: [
          // Preferences button
          // IconButton(
          //   icon: Icon(
          //     Icons.settings,
          //     color: isDark ? AppColors.neutral200 : AppColors.neutral900,
          //     size: 24,
          //   ),
          //   tooltip: 'Preferences',
          //   onPressed: () => PreferencesBottomSheet.show(context),
          // ),
        ],
      ),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.authLoginSuccess),
                backgroundColor: Color(0xFF00A63E),
              ),
            );
            // Pop back to account page (which will detect logged-in state)
            Navigator.of(context).popUntil((route) => route.isFirst);
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: Stack(
          children: [
            const Positioned.fill(child: SentryBackground(variant: 1)),
            SafeArea(
              child: SentryPageEntrance(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 24),

                        // ── Logo ──
                        _buildLogo(isDark),

                        const SizedBox(height: 32),

                        // ── Heading ──
                        Text(
                          l10n.authWelcomeBack,
                          style: AppTextStyles.text2(context).copyWith(
                            color: isDark ? Colors.white : SentryPalette.ink,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 8),

                        Text(
                          l10n.authLoginToAccount,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontWeight: FontWeight.w400,
                            fontSize: 16,
                            height: 1.17,
                            color: isDark
                                ? SentryPalette.softViolet
                                : SentryPalette.violet.withValues(alpha: 0.75),
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 32),

                        // ── Email Field ──
                        _buildTextField(
                          controller: _emailController,
                          fieldKey: const Key('login_email_field'),
                          semanticsIdentifier: 'login_email_field',
                          label: l10n.authEmailAddress,
                          hintText: l10n.authEnterYourEmail,
                          keyboardType: TextInputType.emailAddress,
                          isDark: isDark,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return l10n.authPleaseEnterEmail;
                            }
                            if (!RegExp(
                              r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$',
                            ).hasMatch(value)) {
                              return l10n.authPleaseEnterValidEmail;
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        // ── Password Field ──
                        _buildTextField(
                          controller: _passwordController,
                          fieldKey: const Key('login_password_field'),
                          semanticsIdentifier: 'login_password_field',
                          label: l10n.authPassword,
                          hintText: l10n.authEnterYourPassword,
                          isDark: isDark,
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: SentryPalette.violet.withValues(
                                alpha: 0.7,
                              ),
                              size: 20,
                            ),
                            onPressed: () {
                              setState(
                                () => _obscurePassword = !_obscurePassword,
                              );
                            },
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return l10n.authPleaseEnterPassword;
                            }
                            if (value.length < 6) {
                              return l10n.authPasswordMinLength;
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 12),

                        // ── Forgot Password ──
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ForgotPasswordPage(),
                                ),
                              );
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: SentryPalette.violet,
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              l10n.authForgotPasswordTitle,
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                height: 1.17,
                                color: SentryPalette.violet,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ── Login Button ──
                        BlocBuilder<AuthBloc, AuthState>(
                          builder: (context, state) {
                            final isLoading = state is AuthLoading;
                            return Container(
                              height: 54,
                              decoration: BoxDecoration(
                                gradient: SentryPalette.brandGradient,
                                borderRadius: BorderRadius.circular(54),
                                boxShadow: [
                                  BoxShadow(
                                    color: SentryPalette.violet.withValues(
                                      alpha: 0.35,
                                    ),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Semantics(
                                identifier: 'login_submit_button',
                                button: true,
                                child: ElevatedButton(
                                  key: const Key('login_submit_button'),
                                  onPressed: isLoading ? null : _handleLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    foregroundColor: AppColors.white,
                                    disabledBackgroundColor: Colors.transparent,
                                    elevation: 0,
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
                                  child: isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  AppColors.white,
                                                ),
                                          ),
                                        )
                                      : Text(l10n.authLogin),
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 36),

                        // ── Sign Up Link ──
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              l10n.authNoAccountPrompt,
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontWeight: FontWeight.w400,
                                fontSize: 14,
                                height: 1.17,
                                color: isDark
                                    ? AppColors.neutral400
                                    : AppColors.neutral600,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) => const SignUpPage(),
                                  ),
                                );
                              },
                              child: Text(
                                l10n.authSignUp,
                                style: const TextStyle(
                                  fontFamily: 'Roboto',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  height: 1.17,
                                  color: SentryPalette.violet,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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

  Widget _buildTextField({
    required TextEditingController controller,
    required Key fieldKey,
    required String semanticsIdentifier,
    required String label,
    required String hintText,
    required bool isDark,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w600,
            fontSize: 14,
            height: 1.17,
            color: isDark ? SentryPalette.softViolet : SentryPalette.ink,
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          identifier: semanticsIdentifier,
          textField: true,
          child: TextFormField(
            key: fieldKey,
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText,
            validator: validator,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 14,
              color: isDark ? Colors.white : SentryPalette.ink,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 14,
                color: isDark
                    ? SentryPalette.softViolet.withValues(alpha: 0.5)
                    : SentryPalette.violet.withValues(alpha: 0.4),
              ),
              suffixIcon: suffixIcon,
              filled: true,
              fillColor: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : SentryPalette.softViolet.withValues(alpha: 0.45),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : SentryPalette.softViolet.withValues(alpha: 0.45),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: SentryPalette.violet,
                  width: 1.5,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.red),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
