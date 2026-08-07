# سياق مشروع Flutter — تطبيق المتجر الإلكتروني

## اللغة
أجب دائماً باللغة العربية في كل الردود والتعليقات والشرح.

---

## نظرة عامة
- تطبيق Flutter لنظام Bagisto (متجر إلكتروني).
- يعمل على Android وiPhone.
- الباك إند: Bagisto/Laravel على http://127.0.0.1:8000 (بيئة محلية).
- التواصل مع الباك إند عبر **GraphQL** حصراً (مسار: /graphql).
- **تحذير مهم للاختبار على أجهزة Android:** استخدم 10.0.2.2 بدل 127.0.0.1.

---

## بنية المشروع المهمة

### الثوابت والإعدادات
- `lib/core/constants/api_config.dart` — عنوان الخادم الأساسي (ApiConfig.origin).
- `lib/core/constants/api_constants.dart` — ثوابت الـ API.
- `lib/core/graphql/queries.dart` — كل استعلامات GraphQL.

### الصفحة الرئيسية (البنرات والمحتوى)
- `lib/features/home/data/models/home_models.dart` — نماذج البيانات بما فيها BannerImage وBannerType.
- `lib/features/home/data/repository/home_repository.dart` — جلب بيانات الصفحة الرئيسية.
- `lib/features/home/presentation/bloc/home_bloc.dart` — حالة الصفحة الرئيسية.
- `lib/features/home/presentation/pages/home_page.dart` — الصفحة الرئيسية وعرض البنرات.
- `lib/features/home/presentation/widgets/image_carousel.dart` — ودجت كاروسيل البنرات.

---

## نظام البنرات (البند 15 من مواصفات الزبون)

### الباك إند (Bagisto)
- البنرات تُحفظ في `theme_customization_translations.options` كـ JSON.
- البنية المطلوبة: `{"images": [{...}, {...}]}` (ليس مصفوفة مباشرة).
- كل بنر فيه: title, image, imageUrl, link, banner_type, subtitle, button_text, start_date, end_date, sort_order, status.

### أنواع البنرات (banner_type)
- `main` → يظهر أعلى الصفحة الرئيسية.
- `offers` → يظهر بعد قائمة المنتجات.
- `seasonal` → يظهر بعد بنر العروض.
- `category` → مخصص لصفحة القسم (لم يُنفَّذ بعد).

### مشكلة imageUrl (محلولة)
- الخادم يرسل `imageUrl` ناقصاً: `http://127.0.0.1:8000/theme/10/xxx.png`
- الرابط الصحيح: `http://127.0.0.1:8000/storage/theme/10/xxx.png`
- الحل في `fullImageUrl()` في `home_models.dart`: إن كان الرابط يحوي `/theme/` بلا `/storage/`، يُصلح تلقائياً.
- استعلام GraphQL يطلب `imageUrl` و`image` معاً.

### الاستعلام الصحيح للبنرات
```graphql
query {
  themeCustomization {
    type
    translations {
      options {
        images {
          title
          image
          imageUrl
          link
          banner_type
          subtitle
          button_text
          sort_order
          status
          start_date
          end_date
        }
      }
    }
  }
}
```

### منطق العرض في home_page.dart
البنرات تُفرز حسب النوع وتُعرض في أماكن مختلفة:
- `main` → أعلى الصفحة (قبل الأقسام).
- `offers` و `seasonal` → أسفل قائمة المنتجات.
- الفرز يعتمد على `sort_order`، والإظهار يعتمد على `status` + `start_date`/`end_date`.

---

## تعديلات مهمة تمت على المشروع

### queries.dart
- أُضيف حقل `imageUrl` لاستعلام الثيم (images block).
- أُضيف `imageUrl` للحقول المطلوبة.

### home_models.dart
- `BannerImage.fromJson`: يقرأ `imageUrl` أولاً (الأولوية)، ثم `image` كاحتياطي.
- أُضيف `enum BannerType` (main/offers/seasonal/category).
- أُضيفت حقول: bannerType, subtitle, buttonText, sortOrder, status, startDate, endDate.
- `fullImageUrl()`: يصلح روابط الخادم الناقصة (`/theme/` → `/storage/theme/`).
- `isVisible`: يتحقق من status + الجدولة الزمنية.

### home_page.dart
- البنرات تُفرز حسب BannerType وتُعرض في أقسام منفصلة.

### image_carousel.dart
- أُضيفت طبقة نصية فوق الصورة (subtitle + buttonText).

---

## قواعد لا تخالفها
- لا تعدّل أي ملف في vendor/ أو node_modules/.
- التواصل مع الباك إند عبر GraphQL فقط — لا REST.
- عند الاختبار على Android emulator: غيّر 127.0.0.1 إلى 10.0.2.2 مؤقتاً.

---

## الخطوات التالية المتبقية
- [ ] التحقق من ظهور صور البنرات في الموبايل (مشكلة imageUrl محلولة نظرياً).
- [ ] إضافة Pull-to-Refresh (سحب للأسفل لإعادة التحميل) في home_page.dart.
- [ ] عرض بنرات نوع `category` داخل صفحة القسم.
