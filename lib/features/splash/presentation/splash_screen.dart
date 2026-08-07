import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// شاشة ترحيبية واحدة تعرض صورة (assets/images/splash.png) كاملة في المنتصف
/// على خلفية بيضاء، مع تأثير نبض وحركة خفيفة أثناء تحميل التطبيق.
class SplashScreen extends StatefulWidget {
  final Widget nextScreen;

  const SplashScreen({super.key, required this.nextScreen});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale; // النبض (تكبير/تصغير)
  late final Animation<double> _fade; // ظهور تدريجي ناعم

  @override
  void initState() {
    super.initState();

    // إبقاء تجربة ملء الشاشة
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    // متحكّم الحركة: ينبض ذهابًا وإيابًا باستمرار أثناء التحميل
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    // النبض من الحجم الكامل (1.0) وحتى 0.8 حتى تبقى الصورة مالئة للشاشة دائمًا
    _scale = Tween<double>(
      begin: 0.7,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    // ظهور تدريجي لطيف في البداية
    _fade = Tween<double>(
      begin: 0.7,
      end: 0.8,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    // كرّر النبض ذهابًا وإيابًا
    _controller.repeat(reverse: true);

    // الانتقال إلى الشاشة التالية بعد ثانيتين
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => widget.nextScreen));
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    // استعادة أشرطة النظام عند مغادرة الشاشة
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _fade.value,
              child: Transform.scale(scale: _scale.value, child: child),
            );
          },
          // الصورة تملأ الشاشة بالكامل (وضع ملء الشاشة)
          child: SizedBox.expand(
            child: Image.asset(
              'assets/images/splash.png',
              fit: BoxFit.cover,
              // في حال عدم وجود الصورة بعد، لا نُظهر أيقونة كسر — نُبقي الخلفية بيضاء
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}
