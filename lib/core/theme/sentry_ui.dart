import 'dart:math' as math;
import 'package:flutter/material.dart';

/// ── Sentry Food UI styling (visual-only) ──
///
/// This file holds purely cosmetic constants and helper widgets used to
/// restyle the app to match the "Sentry Food" brand. It does NOT replace
/// the global [AppColors] tokens and contains NO business logic, no Bloc
/// references, and no function-name changes. Screens import it only for
/// colors, gradients, and decorative background shapes.
class SentryPalette {
  SentryPalette._();

  static const Color blue = Color(0xFF9C8DFF);
  static const Color lilac = Color(0xFFCDB8FF);
  static const Color violet = Color(0xFFB28CFF);
  static const Color softViolet = Color(0xFFEFE3FF);
  static const Color ink = Color.fromARGB(255, 53, 48, 121);

  /// Soft page background (light mode).
  static const Color pageLight = Color(0xFFF7F6FF);

  /// Primary brand gradient (blue → violet) for buttons and key accents.
  static const Gradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE6D6FF), Color(0xFFB28CFF)],
  );

  /// Alternate gradient (lilac → violet) for variety across screens.
  static const Gradient lilacGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEADFFF), Color(0xFFB28CFF)],
  );

  /// Cool gradient (blue → lilac) for headers/cards.
  static const Gradient skyGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFE6D6FF), Color(0xFFCDB8FF)],
  );

  static Color pageBackground(bool isDark) =>
      isDark ? const Color.fromARGB(255, 87, 80, 180) : pageLight;
}

/// Decorative, non-interactive background made of soft blurred-looking
/// circles + one rounded square. Drop it behind page content inside a Stack.
///
/// Usage:
///   Stack(children: [
///     const Positioned.fill(child: SentryBackground()),
///     ...your content...
///   ])
class SentryBackground extends StatelessWidget {
  const SentryBackground({super.key, this.variant = 0});

  /// Selects one of several decorative arrangements so each screen looks
  /// distinct. Any integer is accepted (it wraps around).
  final int variant;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Clearly visible (but still soft) tints so the shapes read on every
    // screen, including sparse states like error / no-connection views.
    final softV = SentryPalette.softViolet.withValues(
      alpha: isDark ? 0.10 : 0.24,
    );
    final blue = SentryPalette.blue.withValues(alpha: isDark ? 0.10 : 0.18);
    final violet = SentryPalette.violet.withValues(alpha: isDark ? 0.08 : 0.12);
    final lilac = SentryPalette.lilac.withValues(alpha: isDark ? 0.10 : 0.18);
    final ringColor = SentryPalette.violet.withValues(
      alpha: isDark ? 0.12 : 0.16,
    );

    final layout = ((variant % 8) + 8) % 8;

    final List<Widget> shapes;
    switch (layout) {
      case 0:
        shapes = [
          Positioned(
            top: -60,
            right: -50,
            child: _gradientCircle(220, blue, softV),
          ),
          Positioned(top: 130, left: -60, child: _circle(150, lilac)),
          Positioned(
            bottom: -50,
            right: -40,
            child: _gradientCircle(230, violet, softV),
          ),
          Positioned(bottom: 180, left: 24, child: _ring(96, ringColor)),
          Positioned(
            top: 300,
            right: 36,
            child: _roundedSquare(58, softV, math.pi / 6),
          ),
        ];
        break;
      case 1:
        shapes = [
          Positioned(
            top: -50,
            left: -50,
            child: _gradientCircle(210, softV, blue),
          ),
          Positioned(top: 170, right: -55, child: _circle(160, blue)),
          Positioned(
            bottom: -60,
            left: -40,
            child: _gradientCircle(240, violet, lilac),
          ),
          Positioned(top: 110, right: 32, child: _ring(84, ringColor)),
          Positioned(
            bottom: 170,
            right: 28,
            child: _roundedSquare(76, lilac, math.pi / 5),
          ),
        ];
        break;
      case 2:
        shapes = [
          Positioned(top: -60, right: -30, child: _circle(190, lilac)),
          Positioned(
            top: 90,
            left: -60,
            child: _gradientCircle(210, blue, softV),
          ),
          Positioned(bottom: -40, right: -50, child: _ring(170, ringColor)),
          Positioned(
            bottom: 150,
            left: 28,
            child: _gradientCircle(150, violet, softV),
          ),
          Positioned(
            top: 330,
            right: 44,
            child: _roundedSquare(54, softV, -math.pi / 7),
          ),
        ];
        break;
      case 3:
        shapes = [
          Positioned(top: -40, left: -40, child: _circle(170, softV)),
          Positioned(
            top: 210,
            right: -55,
            child: _gradientCircle(215, violet, lilac),
          ),
          Positioned(bottom: -70, left: -50, child: _circle(230, blue)),
          Positioned(top: 140, left: 30, child: _ring(74, ringColor)),
          Positioned(
            bottom: 190,
            right: 26,
            child: _roundedSquare(72, lilac, math.pi / 4),
          ),
        ];
        break;
      case 4:
        // (كان default سابقًا) تخطيط عام
        shapes = [
          Positioned(
            top: -55,
            right: -45,
            child: _gradientCircle(215, blue, lilac),
          ),
          Positioned(top: 150, left: -55, child: _ring(120, ringColor)),
          Positioned(bottom: -45, right: -35, child: _circle(200, violet)),
          Positioned(
            bottom: 210,
            left: 26,
            child: _gradientCircle(150, softV, blue),
          ),
          Positioned(
            top: 320,
            left: 44,
            child: _roundedSquare(60, softV, math.pi / 5),
          ),
        ];
        break;
      case 5:
        // تخطيط مميّز لشاشة الحساب — دوائر متدرّجة كبيرة في الزوايا العلوية
        // وحلقات وسطية، مع مربّعين صغيرين للتوازن.
        shapes = [
          Positioned(
            top: -70,
            left: -60,
            child: _gradientCircle(250, softV, lilac),
          ),
          Positioned(
            top: -40,
            right: -70,
            child: _gradientCircle(180, blue, violet),
          ),
          Positioned(top: 260, left: -50, child: _ring(140, ringColor)),
          Positioned(
            bottom: 120,
            right: -40,
            child: _gradientCircle(200, violet, softV),
          ),
          Positioned(
            top: 190,
            right: 40,
            child: _roundedSquare(50, lilac, math.pi / 3),
          ),
          Positioned(
            bottom: 60,
            left: 34,
            child: _roundedSquare(44, softV, -math.pi / 6),
          ),
        ];
        break;
      case 6:
        // تخطيط مميّز لشاشة الإعدادات — تركيبة قطرية: دائرة سفلية كبيرة،
        // حلقتان، ودائرة علوية صغيرة، بتوزيع مختلف عن باقي الشاشات.
        shapes = [
          Positioned(top: -50, right: -40, child: _circle(150, lilac)),
          Positioned(
            top: 120,
            left: -70,
            child: _gradientCircle(230, blue, softV),
          ),
          Positioned(top: 90, right: 30, child: _ring(70, ringColor)),
          Positioned(
            bottom: -80,
            right: -50,
            child: _gradientCircle(280, violet, lilac),
          ),
          Positioned(bottom: 200, left: -30, child: _ring(110, ringColor)),
          Positioned(
            top: 300,
            left: 40,
            child: _roundedSquare(56, softV, math.pi / 4),
          ),
        ];
        break;
      case 7:
        // تخطيط مميّز لشاشة إعدادات الحساب (القائمة) — دوائر جانبية متقابلة
        // وحلقة سفلية كبيرة، مع مربّع علوي مائل.
        shapes = [
          Positioned(
            top: 60,
            left: -80,
            child: _gradientCircle(220, softV, blue),
          ),
          Positioned(top: 20, right: -60, child: _circle(140, lilac)),
          Positioned(
            top: 250,
            right: -70,
            child: _gradientCircle(200, blue, violet),
          ),
          Positioned(bottom: -90, left: -60, child: _ring(240, ringColor)),
          Positioned(
            bottom: 140,
            right: 30,
            child: _gradientCircle(120, violet, softV),
          ),
          Positioned(
            top: -30,
            left: 60,
            child: _roundedSquare(52, softV, math.pi / 5),
          ),
        ];
        break;
      default:
        // لا يُستدعى عمليًا (layout دائمًا 0..6) لكنه مطلوب نحويًا.
        shapes = const [];
    }

    // clipBehavior: none lets shapes bleed past the edges naturally instead
    // of being hard-clipped to a rectangle.
    return IgnorePointer(
      child: Stack(clipBehavior: Clip.none, children: shapes),
    );
  }

  Widget _circle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  /// Soft two-tone circle for a bit of depth (no harsh edges).
  Widget _gradientCircle(double size, Color a, Color b) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [a, b],
        ),
      ),
    );
  }

  /// Outlined ring (hollow circle) — adds variety vs. solid blobs.
  Widget _ring(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 14),
      ),
    );
  }

  Widget _roundedSquare(double size, Color color, double angle) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(size * 0.32),
        ),
      ),
    );
  }
}

/// A reusable gradient pill button with built-in loading state and a soft
/// press (scale) animation. Pure presentation — pass your own onPressed.
class SentryGradientButton extends StatefulWidget {
  const SentryGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.gradient = SentryPalette.brandGradient,
    this.height = 54,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Gradient gradient;
  final double height;

  @override
  State<SentryGradientButton> createState() => _SentryGradientButtonState();
}

class _SentryGradientButtonState extends State<SentryGradientButton> {
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
          height: widget.height,
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(widget.height),
            boxShadow: [
              BoxShadow(
                color: SentryPalette.violet.withValues(
                  alpha: _pressed ? 0.28 : 0.45,
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
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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

/// Wraps any page body with a soft Sentry background + a gentle
/// fade/slide intro animation. Logic-free.
class SentryPageEntrance extends StatefulWidget {
  const SentryPageEntrance({super.key, required this.child});

  final Widget child;

  @override
  State<SentryPageEntrance> createState() => _SentryPageEntranceState();
}

class _SentryPageEntranceState extends State<SentryPageEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
