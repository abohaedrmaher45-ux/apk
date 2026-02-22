#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
🔑 مولّد أكواد تفعيل التطبيق
=====================================
هذا السكريبت يقوم بتوليد كود تفعيل فريد لكل جهاز بناءً على Device ID
"""

import hashlib
import sys

# المفتاح السري (يجب أن يطابق المفتاح في ValidationService.dart)
SECRET_KEY = "MySuperSecretKey2024"

def generate_activation_code(device_id):
    """
    توليد كود التفعيل بناءً على معرف الجهاز
    
    Args:
        device_id (str): معرف الجهاز الفريد
    
    Returns:
        str: كود التفعيل (16 حرف بأحرف كبيرة)
    """
    combined = device_id + SECRET_KEY
    hash_object = hashlib.sha256(combined.encode())
    full_hash = hash_object.hexdigest()
    
    # نأخذ أول 16 حرف ونجعلها بأحرف كبيرة
    activation_code = full_hash[:16].upper()
    return activation_code

def print_separator():
    """طباعة خط فاصل"""
    print("=" * 60)

def main():
    """الدالة الرئيسية"""
    print_separator()
    print("🔑 مولّد أكواد التفعيل للتطبيق")
    print_separator()
    print()
    
    # التحقق من وجود معامل في سطر الأوامر
    if len(sys.argv) > 1:
        device_id = sys.argv[1].strip()
    else:
        # طلب معرف الجهاز من المستخدم
        print("📝 أدخل معرف الجهاز (Device ID):")
        print("   (يمكنك الحصول عليه من تطبيق Device Info أو من المستخدم)")
        print()
        device_id = input("📱 Device ID: ").strip()
    
    print()
    
    if not device_id:
        print("❌ خطأ: لم يتم إدخال معرف الجهاز!")
        print("الاستخدام: python3 generate_activation_code.py <DEVICE_ID>")
        sys.exit(1)
    
    # توليد كود التفعيل
    activation_code = generate_activation_code(device_id)
    
    # عرض النتائج
    print_separator()
    print("✅ تم توليد كود التفعيل بنجاح!")
    print_separator()
    print()
    print(f"📱 معرف الجهاز:     {device_id}")
    print(f"🔐 كود التفعيل:     {activation_code}")
    print()
    print_separator()
    print("📋 تعليمات الاستخدام:")
    print_separator()
    print("1. قم بنسخ كود التفعيل أعلاه")
    print("2. أرسله للمستخدم مع اسم المستخدم")
    print("3. المستخدم سيدخل البيانات في شاشة التفعيل:")
    print("   - اسم المستخدم: أي اسم (مثال: أحمد)")
    print(f"   - كود التفعيل: {activation_code}")
    print()
    print("⚠️  ملاحظة: كود التفعيل مرتبط بهذا الجهاز فقط ولن يعمل على أجهزة أخرى")
    print()

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n❌ تم إلغاء العملية من قبل المستخدم")
        sys.exit(0)
    except Exception as e:
        print(f"\n❌ حدث خطأ: {e}")
        sys.exit(1)
