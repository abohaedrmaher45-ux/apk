import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sentry_ui.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../bloc/auth_bloc.dart';

/// Forgot Password page
/// Bagisto API: createForgotPassword
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(
        AuthForgotPasswordRequested(email: _emailController.text.trim()),
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
        leading: AppBackButton(size: 24),
        leadingWidth: 60,
      ),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthForgotPasswordSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: const Color(0xFF00A63E),
              ),
            );
            Navigator.of(context).pop();
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 40),

                      // ── Logo ──
                      _buildLogo(isDark),

                      const SizedBox(height: 32),

                      Text(
                        l10n.authForgotPasswordTitle,
                        style: AppTextStyles.text2(context),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 8),

                      Text(
                        l10n.authForgotPasswordSubtitle,
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontWeight: FontWeight.w400,
                          fontSize: 14,
                          height: 1.5,
                          color: isDark
                              ? AppColors.neutral400
                              : AppColors.neutral600,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 32),

                      // ── Email Field ──
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.authEmailAddress,
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                              height: 1.17,
                              color: isDark
                                  ? AppColors.neutral300
                                  : AppColors.neutral800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
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
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 14,
                              color: isDark
                                  ? AppColors.neutral200
                                  : AppColors.neutral900,
                            ),
                            decoration: InputDecoration(
                              hintText: l10n.authEnterYourEmail,
                              hintStyle: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 14,
                                color: isDark
                                    ? AppColors.neutral500
                                    : AppColors.neutral400,
                              ),
                              filled: true,
                              fillColor: isDark
                                  ? AppColors.neutral800
                                  : AppColors.neutral50,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? AppColors.neutral700
                                      : AppColors.neutral200,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? AppColors.neutral700
                                      : AppColors.neutral200,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: AppColors.primary500,
                                  width: 1.5,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.red),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // ── Submit Button ──
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
                                    alpha: 0.30,
                                  ),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: isLoading ? null : _handleSubmit,
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
                                  : Text(l10n.authSendResetLink),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 24),

                      // ── Back to Login ──
                      Center(
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Text(
                            l10n.authBackToLogin,
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              height: 1.17,
                              color: AppColors.primary500,
                            ),
                          ),
                        ),
                      ),
                    ],
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
}
