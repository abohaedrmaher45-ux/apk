#!/bin/bash

# 🔐 سكريبت إنشاء نسخة محمية من تطبيق Maherkh
# الاستخدام: ./create_client_build.sh <client_number> <client_name>

set -e

# الألوان
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# التحقق من المعاملات
if [ "$#" -lt 2 ]; then
    echo -e "${RED}❌ خطأ في الاستخدام${NC}"
    echo "الاستخدام: ./create_client_build.sh <client_number> <client_name>"
    echo "مثال: ./create_client_build.sh 001 \"Ahmed Store\""
    exit 1
fi

CLIENT_NUM=$1
CLIENT_NAME=$2
PROJECT_DIR="/home/user/Maherkh"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🔐 نظام إنشاء نسخة محمية - Maherkh App${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 1. توليد معرف ترخيص عشوائي
echo -e "${YELLOW}📝 الخطوة 1: توليد معرف ترخيص فريد...${NC}"
RANDOM_CODE=$(cat /dev/urandom | tr -dc 'A-Z0-9' | fold -w 10 | head -n 1)
LICENSE_ID="MAHER_CLIENT_${CLIENT_NUM}_${RANDOM_CODE}"
echo -e "${GREEN}✅ معرف الترخيص: ${LICENSE_ID}${NC}"
echo ""

# 2. تحديث ملف app_license.dart
echo -e "${YELLOW}📝 الخطوة 2: تحديث ملف الترخيص...${NC}"
LICENSE_FILE="${PROJECT_DIR}/lib/core/config/app_license.dart"
CURRENT_DATE=$(date +%Y-%m-%d)

# إنشاء نسخة احتياطية
cp "$LICENSE_FILE" "${LICENSE_FILE}.backup"

# تحديث الملف
sed -i "s/static const String UNIQUE_LICENSE_ID = '[^']*';/static const String UNIQUE_LICENSE_ID = '${LICENSE_ID}';/" "$LICENSE_FILE"
sed -i "s/static const String ISSUE_DATE = '[^']*';/static const String ISSUE_DATE = '${CURRENT_DATE}';/" "$LICENSE_FILE"
sed -i "s/static const String CLIENT_NAME = '[^']*';/static const String CLIENT_NAME = '${CLIENT_NAME}';/" "$LICENSE_FILE"

echo -e "${GREEN}✅ تم تحديث معلومات الترخيص${NC}"
echo "   - معرف الترخيص: ${LICENSE_ID}"
echo "   - اسم العميل: ${CLIENT_NAME}"
echo "   - تاريخ الإصدار: ${CURRENT_DATE}"
echo ""

# 3. تنظيف المشروع
echo -e "${YELLOW}📝 الخطوة 3: تنظيف المشروع...${NC}"
cd "$PROJECT_DIR"
flutter clean > /dev/null 2>&1
echo -e "${GREEN}✅ تم تنظيف المشروع${NC}"
echo ""

# 4. تثبيت المكتبات
echo -e "${YELLOW}📝 الخطوة 4: تثبيت المكتبات...${NC}"
flutter pub get > /dev/null 2>&1
echo -e "${GREEN}✅ تم تثبيت المكتبات${NC}"
echo ""

# 5. بناء APK مشفر
echo -e "${YELLOW}📝 الخطوة 5: بناء APK مشفر (قد يستغرق بضع دقائق)...${NC}"
DEBUG_INFO_DIR="build/debug-info/client_${CLIENT_NUM}"
flutter build apk --release \
    --obfuscate \
    --split-debug-info="$DEBUG_INFO_DIR" \
    > build_log.txt 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ تم بناء APK بنجاح${NC}"
else
    echo -e "${RED}❌ فشل بناء APK. راجع ملف build_log.txt${NC}"
    exit 1
fi
echo ""

# 6. إنشاء مجلد الإصدار
echo -e "${YELLOW}📝 الخطوة 6: تنظيم ملفات الإصدار...${NC}"
RELEASE_DIR="releases/client_${CLIENT_NUM}_${CLIENT_NAME// /_}"
mkdir -p "$RELEASE_DIR"
mkdir -p "${RELEASE_DIR}/debug_symbols"

# نسخ الملفات
cp build/app/outputs/flutter-apk/app-release.apk "${RELEASE_DIR}/maherkh_${CLIENT_NAME// /_}.apk"
cp -r "$DEBUG_INFO_DIR"/* "${RELEASE_DIR}/debug_symbols/" 2>/dev/null || true

# إنشاء ملف معلومات
cat > "${RELEASE_DIR}/LICENSE_INFO.txt" << EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔐 معلومات الترخيص - تطبيق Maherkh
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📋 معلومات العميل:
   - رقم العميل: ${CLIENT_NUM}
   - اسم العميل: ${CLIENT_NAME}
   - تاريخ الإصدار: ${CURRENT_DATE}

🔑 معلومات الترخيص:
   - معرف الترخيص: ${LICENSE_ID}
   - نوع الترخيص: جهاز واحد فقط
   - حالة الحماية: مُفعّلة

📦 ملفات الإصدار:
   - APK: maherkh_${CLIENT_NAME// /_}.apk
   - ملفات فك التشفير: debug_symbols/

⚠️ ملاحظات مهمة:
   1. هذا التطبيق مرخص لجهاز واحد فقط
   2. لا يمكن نسخه أو مشاركته لأجهزة أخرى
   3. عند أول تشغيل، سيتم ربط التطبيق بالجهاز
   4. احتفظ بملفات debug_symbols للدعم الفني

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

echo -e "${GREEN}✅ تم تنظيم ملفات الإصدار${NC}"
echo ""

# 7. إنشاء أرشيف مضغوط
echo -e "${YELLOW}📝 الخطوة 7: إنشاء أرشيف مضغوط...${NC}"
cd releases
tar -czf "client_${CLIENT_NUM}_${CLIENT_NAME// /_}.tar.gz" "client_${CLIENT_NUM}_${CLIENT_NAME// /_}"
cd ..
echo -e "${GREEN}✅ تم إنشاء الأرشيف المضغوط${NC}"
echo ""

# 8. استعادة ملف الترخيص (للمطور)
mv "${LICENSE_FILE}.backup" "$LICENSE_FILE"
echo -e "${GREEN}✅ تم استعادة ملف الترخيص الأصلي${NC}"
echo ""

# النتيجة النهائية
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ تم إنشاء النسخة بنجاح!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}📂 مسار الملفات:${NC}"
echo "   ${RELEASE_DIR}/"
echo ""
echo -e "${YELLOW}📦 الملفات المُنشأة:${NC}"
echo "   1. maherkh_${CLIENT_NAME// /_}.apk - التطبيق للتسليم للعميل"
echo "   2. LICENSE_INFO.txt - معلومات الترخيص"
echo "   3. debug_symbols/ - ملفات فك التشفير (احفظها)"
echo "   4. client_${CLIENT_NUM}_${CLIENT_NAME// /_}.tar.gz - أرشيف كامل"
echo ""
echo -e "${YELLOW}📝 معلومات الترخيص:${NC}"
echo "   معرف الترخيص: ${GREEN}${LICENSE_ID}${NC}"
echo "   العميل: ${GREEN}${CLIENT_NAME}${NC}"
echo "   التاريخ: ${GREEN}${CURRENT_DATE}${NC}"
echo ""
echo -e "${YELLOW}⚠️  تذكير مهم:${NC}"
echo "   - احفظ معرف الترخيص في قاعدة بيانات العملاء"
echo "   - احتفظ بملفات debug_symbols للدعم الفني"
echo "   - هذه النسخة تعمل على جهاز واحد فقط"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
