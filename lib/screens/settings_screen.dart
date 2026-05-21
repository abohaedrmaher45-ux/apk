// lib/screens/settings_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:share_plus/share_plus.dart';        // ✅ أضف هذا
import 'package:path_provider/path_provider.dart';  // ✅ أضف هذا
import '../services/storage_service.dart';
import '../utils/app_constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final StorageService storage = StorageService.instance;
  bool _isBackingUp = false;
  bool _isRestoring = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          
          // قسم النسخ الاحتياطي
          _buildSection(
            title: 'النسخ الاحتياطي',
            icon: Icons.backup,
            children: [
              ListTile(
                leading: const Icon(Icons.cloud_upload, color: Colors.green),
                title: const Text('نسخ احتياطي'),
                subtitle: const Text('حفظ البيانات على الجهاز'),
                trailing: _isBackingUp
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator())
                    : const Icon(Icons.arrow_forward),
                onTap: _backupData,
              ),
              ListTile(
                leading: const Icon(Icons.cloud_download, color: Colors.orange),
                title: const Text('استعادة البيانات'),
                subtitle: const Text('استعادة البيانات من ملف سابق'),
                trailing: _isRestoring
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator())
                    : const Icon(Icons.arrow_forward),
                onTap: _restoreData,
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // قسم معلومات الشركة
          _buildSection(
            title: 'معلومات الشركة',
            icon: Icons.business,
            children: [
              ListTile(
                leading: const Icon(Icons.business_center),
                title: const Text('اسم الشركة'),
                subtitle: Text(AppConstants.companyName),
              ),
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('المدير'),
                subtitle: Text(AppConstants.managerName),
              ),
              ListTile(
                leading: const Icon(Icons.phone),
                title: const Text('الهاتف'),
                subtitle: Text(AppConstants.contactPhone),
              ),
              ListTile(
                leading: const Icon(Icons.location_on),
                title: const Text('العنوان'),
                subtitle: Text(AppConstants.address),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // قسم عن التطبيق
          _buildSection(
            title: 'عن التطبيق',
            icon: Icons.info,
            children: [
              ListTile(
                leading: const Icon(Icons.apps),
                title: const Text('الإصدار'),
                subtitle: const Text('1.0.0'),
              ),
              ListTile(
                leading: const Icon(Icons.code),
                title: const Text('المطور'),
                subtitle: const Text('شركة العجاج للمقاولات'),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildSection({required String title, required IconData icon, required List<Widget> children}) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: AppConstants.primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }
  
  Future<void> _backupData() async {
    setState(() => _isBackingUp = true);
    
    try {
      final backupPath = await storage.backupData();
      
      // عرض خيار المشاركة
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تم النسخ الاحتياطي'),
          content: Text('تم حفظ النسخة الاحتياطية بنجاح.\nهل تريد مشاركة الملف؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('لا'),
            ),
            ElevatedButton(
              onPressed: () async {
                await Share.shareXFiles([XFile(backupPath)]);  // ✅ أصبح يعمل الآن
                if (mounted) Navigator.pop(context);
              },
              child: const Text('مشاركة'),
            ),
          ],
        ),
      );
      
      Fluttertoast.showToast(msg: '✅ تم النسخ الاحتياطي بنجاح');
    } catch (e) {
      Fluttertoast.showToast(msg: '❌ حدث خطأ: $e');
    } finally {
      setState(() => _isBackingUp = false);
    }
  }
  
  Future<void> _restoreData() async {
    setState(() => _isRestoring = true);
    
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      
      if (result != null) {
        final filePath = result.files.single.path!;
        final success = await storage.restoreData(filePath);
        
        if (success) {
          Fluttertoast.showToast(msg: '✅ تم استعادة البيانات بنجاح');
          // إعادة تحميل البيانات
          if (mounted) {
            Navigator.pop(context);
          }
        } else {
          Fluttertoast.showToast(msg: '❌ فشل استعادة البيانات');
        }
      }
    } catch (e) {
      Fluttertoast.showToast(msg: '❌ حدث خطأ: $e');
    } finally {
      setState(() => _isRestoring = false);
    }
  }
}