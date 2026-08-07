import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../bloc/auth_bloc.dart';
import 'login_page.dart';
import 'forgot_password_page.dart';

/// ── Sentry Food UI palette (visual-only, local to this screen) ──
/// These constants are used purely for restyling and do NOT replace
/// the global AppColors tokens used by the rest of the app.
class _SentryPalette {
  static const Color blue = Color(0xFF6EA8FE);
  static const Color lilac = Color(0xFFAB90FF);
  static const Color violet = Color(0xFF885CF6);
  static const Color softViolet = Color(0xFFD6B4FE);
  static const Color ink = Color(0xFF1E1B4B);

  static const Gradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [blue, violet],
  );
}

/// Privacy policy & terms URLs — sourced from the store's own CMS pages
/// (see api_constants.dart). These same pages are also viewable inside the
/// app through Account → Preferences.
const String _kPrivacyPolicyUrl = privacyPolicyUrl;
const String _kTermsOfUseUrl = termsOfUseUrl;

/// Sign Up page for new customers
/// Figma: authentication flow — registration screen
class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  // Visual "full name" field — its value is split into first/last on submit,
  // so the AuthBloc data contract (firstName + lastName) stays unchanged.
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreedToTerms = false;
  bool _showTermsError = false;

  late final AnimationController _introController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideIn;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fadeIn = CurvedAnimation(
      parent: _introController,
      curve: Curves.easeOut,
    );
    _slideIn = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _introController, curve: Curves.easeOutCubic),
    );
    _introController.forward();
  }

  @override
  void dispose() {
    _introController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Splits the visible full name into first + last and feeds the SAME
  /// controllers/event the Bloc already expects. No data contract change.
  void _syncNameControllers() {
    final fullName = _fullNameController.text.trim();
    final parts = fullName.split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) {
      _firstNameController.text = '';
      _lastNameController.text = '';
    } else if (parts.length == 1) {
      _firstNameController.text = parts.first;
      _lastNameController.text = parts.first;
    } else {
      _firstNameController.text = parts.first;
      _lastNameController.text = parts.sublist(1).join(' ');
    }
  }

  void _handleSignUp() {
    final formValid = _formKey.currentState?.validate() ?? false;
    if (!_agreedToTerms) {
      setState(() => _showTermsError = true);
    }
    if (formValid && _agreedToTerms) {
      _syncNameControllers();
      context.read<AuthBloc>().add(
        AuthRegisterRequested(
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          confirmPassword: _confirmPasswordController.text,
        ),
      );
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  bool get _isArabic =>
      Localizations.localeOf(context).languageCode == 'ar';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: isDark ? _SentryPalette.ink : const Color(0xFFF7F6FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: AppBackButton(size: 24),
        leadingWidth: 60,
      ),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.authAccountCreatedSuccess),
                backgroundColor: const Color(0xFF00A63E),
              ),
            );
            Navigator.of(context).popUntil((route) => route.isFirst);
          } else if (state is AuthRegistrationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: const Color(0xFF00A63E),
              ),
            );
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const LoginPage()),
            );
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
            // ── Soft geometric background shapes ──
            Positioned.fill(child: _buildBackgroundShapes(isDark)),

            SafeArea(
              child: FadeTransition(
                opacity: _fadeIn,
                child: SlideTransition(
                  position: _slideIn,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 24),

                          _buildLogo(isDark),

                          const SizedBox(height: 32),

                          Text(
                            l10n.authCreateAccount,
                            style: AppTextStyles.text2(context).copyWith(
                              color: isDark ? Colors.white : _SentryPalette.ink,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 8),

                          Text(
                            l10n.authSignupGetStarted,
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontWeight: FontWeight.w400,
                              fontSize: 16,
                              height: 1.17,
                              color: isDark
                                  ? _SentryPalette.softViolet
                                  : _SentryPalette.violet
                                        .withValues(alpha: 0.75),
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 32),

                          // ── Full Name (single visible field) ──
                          _buildTextField(
                            controller: _fullNameController,
                            label: _isArabic ? 'الاسم الكامل' : 'Full name',
                            hintText: _isArabic
                                ? 'أدخل اسمك الكامل'
                                : 'Enter your full name',
                            isDark: isDark,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return l10n.authRequired;
                              }
                              if (value.trim().split(RegExp(r'\s+')).length < 2) {
                                return _isArabic
                                    ? 'يرجى إدخال الاسم الأول واسم العائلة'
                                    : 'Please enter first and last name';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 16),

                          // ── Email Field ──
                          _buildTextField(
                            controller: _emailController,
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
                            label: l10n.authPassword,
                            hintText: l10n.authCreatePasswordHint,
                            isDark: isDark,
                            obscureText: _obscurePassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: _SentryPalette.violet
                                    .withValues(alpha: 0.7),
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

                          const SizedBox(height: 16),

                          // ── Confirm Password Field ──
                          _buildTextField(
                            controller: _confirmPasswordController,
                            label: l10n.authConfirmPassword,
                            hintText: l10n.authConfirmPasswordHint,
                            isDark: isDark,
                            obscureText: _obscureConfirmPassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: _SentryPalette.violet
                                    .withValues(alpha: 0.7),
                                size: 20,
                              ),
                              onPressed: () {
                                setState(
                                  () => _obscureConfirmPassword =
                                      !_obscureConfirmPassword,
                                );
                              },
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return l10n.authPleaseConfirmPassword;
                              }
                              if (value != _passwordController.text) {
                                return l10n.authPasswordsDoNotMatch;
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 8),

                          // ── Forgot Password link ──
                          Align(
                            alignment: _isArabic
                                ? Alignment.centerLeft
                                : Alignment.centerRight,
                            child: GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const ForgotPasswordPage(),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Text(
                                  l10n.authForgotPasswordTitle,
                                  style: const TextStyle(
                                    fontFamily: 'Roboto',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: _SentryPalette.violet,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // ── GDPR consent ──
                          _buildConsentRow(isDark),

                          const SizedBox(height: 24),

                          // ── Sign Up Button with Loading ──
                          BlocBuilder<AuthBloc, AuthState>(
                            builder: (context, state) {
                              final isLoading = state is AuthLoading;
                              return _GradientButton(
                                isLoading: isLoading,
                                onPressed: isLoading ? null : _handleSignUp,
                                label: l10n.authSignUp,
                              );
                            },
                          ),

                          const SizedBox(height: 36),

                          // ── Login Link ──
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                l10n.authAlreadyHaveAccountPrompt,
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontWeight: FontWeight.w400,
                                  fontSize: 14,
                                  height: 1.17,
                                  color: isDark
                                      ? _SentryPalette.softViolet
                                      : _SentryPalette.violet
                                            .withValues(alpha: 0.7),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(
                                      builder: (_) => const LoginPage(),
                                    ),
                                  );
                                },
                                child: Text(
                                  l10n.authLogin,
                                  style: const TextStyle(
                                    fontFamily: 'Roboto',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    height: 1.17,
                                    color: _SentryPalette.violet,
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
            ),
          ],
        ),
      ),
    );
  }

  // ── GDPR consent row: "I have read and agree to the
  //    Privacy Policy and Terms of Use" with tappable links ──
  Widget _buildConsentRow(bool isDark) {
    final baseColor = isDark
        ? _SentryPalette.softViolet
        : _SentryPalette.ink.withValues(alpha: 0.8);
    final linkStyle = const TextStyle(
      fontFamily: 'Roboto',
      fontSize: 13,
      height: 1.4,
      fontWeight: FontWeight.w700,
      color: _SentryPalette.violet,
      decoration: TextDecoration.underline,
      decorationColor: _SentryPalette.violet,
    );
    final baseStyle = TextStyle(
      fontFamily: 'Roboto',
      fontSize: 13,
      height: 1.4,
      color: baseColor,
    );

    final TextSpan consentSpan = _isArabic
        ? TextSpan(
            style: baseStyle,
            children: [
              const TextSpan(text: 'لقد قرأت وأوافق على '),
              TextSpan(
                text: 'سياسة الخصوصية',
                style: linkStyle,
                recognizer: _tap(_kPrivacyPolicyUrl),
              ),
              const TextSpan(text: ' و'),
              TextSpan(
                text: 'شروط الاستخدام',
                style: linkStyle,
                recognizer: _tap(_kTermsOfUseUrl),
              ),
              const TextSpan(text: '.'),
            ],
          )
        : TextSpan(
            style: baseStyle,
            children: [
              const TextSpan(text: 'I have read and agree to the '),
              TextSpan(
                text: 'Privacy Policy',
                style: linkStyle,
                recognizer: _tap(_kPrivacyPolicyUrl),
              ),
              const TextSpan(text: ' and '),
              TextSpan(
                text: 'Terms of Use',
                style: linkStyle,
                recognizer: _tap(_kTermsOfUseUrl),
              ),
              const TextSpan(text: '.'),
            ],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: _agreedToTerms,
                onChanged: (v) {
                  setState(() {
                    _agreedToTerms = v ?? false;
                    if (_agreedToTerms) _showTermsError = false;
                  });
                },
                activeColor: _SentryPalette.violet,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: RichText(text: consentSpan),
              ),
            ),
          ],
        ),
        if (_showTermsError)
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 2, left: 2),
            child: Text(
              _isArabic
                  ? 'يجب الموافقة على سياسة الخصوصية وشروط الاستخدام للمتابعة.'
                  : 'You must accept the Privacy Policy and Terms to continue.',
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 12,
                color: Colors.red,
              ),
            ),
          ),
      ],
    );
  }

  TapGestureRecognizer _tap(String url) =>
      TapGestureRecognizer()..onTap = () => _openUrl(url);

  Widget _buildBackgroundShapes(bool isDark) {
    final c1 = (isDark ? _SentryPalette.lilac : _SentryPalette.softViolet)
        .withValues(alpha: isDark ? 0.10 : 0.35);
    final c2 = (isDark ? _SentryPalette.blue : _SentryPalette.blue)
        .withValues(alpha: isDark ? 0.10 : 0.22);
    final c3 = (isDark ? _SentryPalette.violet : _SentryPalette.violet)
        .withValues(alpha: isDark ? 0.08 : 0.12);
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -70,
            right: -50,
            child: _circle(180, c1),
          ),
          Positioned(
            top: 120,
            left: -70,
            child: _circle(150, c2),
          ),
          Positioned(
            bottom: -60,
            right: -40,
            child: _circle(200, c3),
          ),
          Positioned(
            bottom: 140,
            left: -30,
            child: Transform.rotate(
              angle: math.pi / 5,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: c1,
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _buildLogo(bool isDark) {
    return Center(
      child: Container(
        height: 96,
        width: 96,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: _SentryPalette.brandGradient,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: _SentryPalette.violet.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SvgPicture.asset(
          'assets/images/bagisto_logo.svg',
          height: 60,
          width: 60,
          colorFilter: const ColorFilter.mode(
            Colors.white,
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
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
            color: isDark ? _SentryPalette.softViolet : _SentryPalette.ink,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          validator: validator,
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 14,
            color: isDark ? Colors.white : _SentryPalette.ink,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 14,
              color: isDark
                  ? _SentryPalette.softViolet.withValues(alpha: 0.5)
                  : _SentryPalette.violet.withValues(alpha: 0.4),
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
                    : _SentryPalette.softViolet.withValues(alpha: 0.45),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : _SentryPalette.softViolet.withValues(alpha: 0.45),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: _SentryPalette.violet,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

/// Gradient pill button with built-in loading state and soft press animation.
class _GradientButton extends StatefulWidget {
  const _GradientButton({
    required this.isLoading,
    required this.onPressed,
    required this.label,
  });

  final bool isLoading;
  final VoidCallback? onPressed;
  final String label;

  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onPressed == null
          ? null
          : (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 54,
          decoration: BoxDecoration(
            gradient: _SentryPalette.brandGradient,
            borderRadius: BorderRadius.circular(54),
            boxShadow: [
              BoxShadow(
                color: _SentryPalette.violet.withValues(
                  alpha: _pressed ? 0.2 : 0.35,
                ),
                blurRadius: _pressed ? 10 : 18,
                offset: Offset(0, _pressed ? 4 : 8),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: widget.isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  widget.label,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    height: 1.17,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}
