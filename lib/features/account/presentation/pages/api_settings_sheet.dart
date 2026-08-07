import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/api_config.dart';
import '../../../../core/theme/app_theme.dart';

/// Developer utility: change the backend API endpoint at runtime.
///
/// Intended for integration testing (e.g. pointing the app at a colleague's
/// machine on the LAN such as `http://192.168.1.126:8001`). The value is saved
/// to SharedPreferences and applied after an app restart.
///
/// This is a dev-only tool; consider hiding it behind a debug flag before
/// production release.
class ApiSettingsSheet extends StatefulWidget {
  const ApiSettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ApiSettingsSheet(),
    );
  }

  @override
  State<ApiSettingsSheet> createState() => _ApiSettingsSheetState();
}

class _ApiSettingsSheetState extends State<ApiSettingsSheet> {
  late final TextEditingController _controller;
  String? _preview;
  String? _error;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ApiConfig.endpoint);
    _recompute(ApiConfig.endpoint);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _recompute(String raw) {
    setState(() {
      _saved = false;
      if (raw.trim().isEmpty) {
        _preview = null;
        _error = null;
        return;
      }
      if (ApiConfig.isValid(raw)) {
        _preview = ApiConfig.normalize(raw);
        _error = null;
      } else {
        _preview = null;
        _error = 'رابط غير صالح — Invalid URL';
      }
    });
  }

  Future<void> _save() async {
    final raw = _controller.text.trim();
    if (!ApiConfig.isValid(raw)) {
      setState(() => _error = 'رابط غير صالح — Invalid URL');
      return;
    }
    final normalized = await ApiConfig.setEndpoint(raw);
    if (!mounted) return;
    setState(() {
      _controller.text = normalized;
      _preview = normalized;
      _saved = true;
    });
  }

  Future<void> _reset() async {
    await ApiConfig.reset();
    if (!mounted) return;
    _controller.text = ApiConfig.defaultEndpoint;
    _recompute(ApiConfig.defaultEndpoint);
    setState(() => _saved = true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.neutral900 : Colors.white;
    final textColor = isDark ? AppColors.neutral100 : AppColors.neutral900;
    final subColor = isDark ? AppColors.neutral400 : AppColors.neutral600;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Grabber
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.neutral700 : AppColors.neutral200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Row(
              children: [
                Icon(Icons.dns_outlined, color: textColor, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'إعدادات الـ API (اختبار)',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'أدخل عنوان السيرفر للاختبار، مثال:\n'
              'http://192.168.1.126:8001',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 13,
                height: 1.4,
                color: subColor,
              ),
            ),
            const SizedBox(height: 16),

            // Input
            TextField(
              controller: _controller,
              onChanged: _recompute,
              keyboardType: TextInputType.url,
              autocorrect: false,
              textDirection: TextDirection.ltr,
              inputFormatters: [
                FilteringTextInputFormatter.deny(RegExp(r'\s')),
              ],
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 15,
                color: textColor,
              ),
              decoration: InputDecoration(
                hintText: 'http://192.168.1.126:8001',
                hintStyle: TextStyle(color: subColor),
                errorText: _error,
                prefixIcon: Icon(Icons.link, color: subColor, size: 20),
                filled: true,
                fillColor:
                    isDark ? AppColors.neutral800 : AppColors.neutral50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark
                        ? AppColors.neutral700
                        : AppColors.neutral200,
                  ),
                ),
              ),
            ),

            // Normalized preview
            if (_preview != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.neutral800
                      : AppColors.neutral50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'سيتصل التطبيق بـ — Endpoint:',
                      style: TextStyle(fontSize: 11, color: subColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _preview!,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_saved) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: Color(0xFF2E9E5B), size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'تم الحفظ. أعد تشغيل التطبيق لتطبيق التغيير.\n'
                      'Saved. Restart the app to apply.',
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: Color(0xFF2E9E5B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 20),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _reset,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                        color: isDark
                            ? AppColors.neutral700
                            : AppColors.neutral300,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'الافتراضي — Reset',
                      style: TextStyle(color: textColor),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _error == null ? _save : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: AppColors.primary500,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('حفظ — Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
