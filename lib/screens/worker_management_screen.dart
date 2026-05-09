import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/worker_index_service.dart';

class WorkerManagementScreen extends StatefulWidget {
  final String? selectedDate;
  const WorkerManagementScreen({super.key, this.selectedDate});
  @override
  State<WorkerManagementScreen> createState() => _WorkerManagementScreenState();
}

class _WorkerManagementScreenState extends State<WorkerManagementScreen> {
  final WorkerIndexService _workerIndexService = WorkerIndexService();
  Map<int, WorkerData> _workersData = {};

  final TextEditingController _addController = TextEditingController();
  final FocusNode _addFocusNode = FocusNode();

  // متحكمات وعُقد تركيز للتعديل المباشر
  Map<String, TextEditingController> _mobileControllers = {};
  Map<String, FocusNode> _mobileFocusNodes = {};
  Map<String, TextEditingController> _balanceControllers = {};
  Map<String, FocusNode> _balanceFocusNodes = {};
  Map<String, TextEditingController> _currencyControllers = {};
  Map<String, FocusNode> _currencyFocusNodes = {};
  @override
  void initState() {
    super.initState();
    _loadWorkers();
  }

  @override
  void dispose() {
    _addController.dispose();
    _addFocusNode.dispose();
    _mobileControllers.values.forEach((c) => c.dispose());
    _mobileFocusNodes.values.forEach((n) => n.dispose());
    _balanceControllers.values.forEach((c) => c.dispose());
    _balanceFocusNodes.values.forEach((n) => n.dispose());
    _currencyControllers.values.forEach((c) => c.dispose());
    _currencyFocusNodes.values.forEach((n) => n.dispose());
    super.dispose();
  }

  Future<void> _loadWorkers() async {
    final workers = await _workerIndexService.getAllWorkersWithData();
    if (mounted) {
      setState(() {
        _workersData = workers;
        _initializeControllersAndNodes();
      });
    }
  }

  void _initializeControllersAndNodes() {
    _mobileControllers.values.forEach((c) => c.dispose());
    _mobileFocusNodes.values.forEach((n) => n.dispose());
    _balanceControllers.values.forEach((c) => c.dispose());
    _balanceFocusNodes.values.forEach((n) => n.dispose());

    _mobileControllers.clear();
    _mobileFocusNodes.clear();
    _balanceControllers.clear();
    _balanceFocusNodes.clear();

    _workersData.forEach((key, worker) {
      // متحكمات وعقد للموبايل
      _mobileControllers[worker.name] =
          TextEditingController(text: worker.mobile);
      _mobileFocusNodes[worker.name] = FocusNode();
      _mobileFocusNodes[worker.name]!.addListener(() {
        if (!_mobileFocusNodes[worker.name]!.hasFocus) {
          _saveMobileEdit(worker.name);
        }
      });

      // متحكمات وعقد للعملة
      _currencyControllers[worker.name] =
          TextEditingController(text: worker.currency);
      _currencyFocusNodes[worker.name] = FocusNode();
      _currencyFocusNodes[worker.name]!.addListener(() {
        if (!_currencyFocusNodes[worker.name]!.hasFocus) {
          _saveCurrencyEdit(worker.name);
        }
      });

      // متحكمات وعقد للأجرة اليومية - بنفس آلية الموبايل
      _balanceControllers[worker.name] = TextEditingController(
          text: worker.balance == 0.0 ? '' : worker.balance.toStringAsFixed(2));
      _balanceFocusNodes[worker.name] = FocusNode();
      _balanceFocusNodes[worker.name]!.addListener(() {
        if (!_balanceFocusNodes[worker.name]!.hasFocus) {
          _saveBalanceEdit(worker.name);
        }
      });
    });
  }

  Future<void> _addNewWorker() async {
    final name = _addController.text.trim();
    if (name.isNotEmpty) {
      // استخدم التاريخ المُمرَّر أو اترك الـ service يتعامل معه
      await _workerIndexService.saveWorker(name,
          startDate: widget.selectedDate);
      _addController.clear();
      _addFocusNode.unfocus();
      await _loadWorkers();
    }
  }

  Future<void> _deleteWorker(WorkerData worker) async {
    if (worker.balance != 0.0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'لا يمكن حذف عامل أجرته اليومية غير صفر (${worker.balance.toStringAsFixed(2)})'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف العامل "${worker.name}"؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف')),
        ],
      ),
    );

    if (confirm == true) {
      await _workerIndexService.removeWorker(worker.name);
      await _loadWorkers();
    }
  }

  Future<void> _saveMobileEdit(String workerName) async {
    final newMobile = _mobileControllers[workerName]?.text.trim() ?? '';
    await _workerIndexService.updateWorkerMobile(workerName, newMobile);
  }

  Future<void> _saveBalanceEdit(String workerName) async {
    final text = _balanceControllers[workerName]?.text.trim() ?? '';
    final newBalance = double.tryParse(text) ?? 0.0;
    await _workerIndexService.setInitialBalance(workerName, newBalance);
  }

  Future<void> _saveCurrencyEdit(String workerName) async {
    final text = _currencyControllers[workerName]?.text.trim() ?? '';
    await _workerIndexService.updateWorkerCurrency(workerName, text);
  }

  @override
  Widget build(BuildContext context) {
    List<MapEntry<int, WorkerData>> sortedEntries =
        _workersData.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    return Scaffold(
      appBar: AppBar(
        title: const Text('أسماء العمال وأجورهم'),
        backgroundColor: Colors.teal[600],
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _addController,
                focusNode: _addFocusNode,
                decoration: InputDecoration(
                  labelText: 'إضافة عامل جديد',
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _addNewWorker(),
              ),
            ),
            // رأس الجدول
            Container(
              color: Colors.grey[300],
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: const [
                  Expanded(
                      flex: 2,
                      child: Text('الاسم',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 11))),
                  Expanded(
                      flex: 2,
                      child: Text('الاجرة',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 11),
                          textAlign: TextAlign.center)),
                  Expanded(
                      flex: 2,
                      child: Text('العملة',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 11),
                          textAlign: TextAlign.center)),
                  Expanded(
                      flex: 3,
                      child: Text('الموبايل',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 11),
                          textAlign: TextAlign.center)),
                  Expanded(
                      flex: 2,
                      child: Text('تاريخ البدء',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 11),
                          textAlign: TextAlign.center)),
                  SizedBox(width: 30),
                ],
              ),
            ),
// قائمة العمال
            Expanded(
              child: sortedEntries.isEmpty
                  ? const Center(child: Text('لا يوجد عمال مسجلين.'))
                  : ListView.builder(
                      itemCount: sortedEntries.length,
                      itemBuilder: (context, index) {
                        final worker = sortedEntries[index].value;
                        final isEven = index % 2 == 0;

                        return Container(
                          color: isEven ? Colors.white : Colors.grey[50],
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          child: Row(
                            children: [
                              Expanded(
                                  flex: 2,
                                  child: Text(worker.name,
                                      style: const TextStyle(fontSize: 13))),
                              Expanded(
                                  flex: 2,
                                  child: _buildEditableCell(
                                    controller:
                                        _balanceControllers[worker.name],
                                    focusNode: _balanceFocusNodes[worker.name],
                                    isNumeric: true,
                                    onSubmitted: (val) {
                                      FocusScope.of(context).requestFocus(
                                          _currencyFocusNodes[worker.name]);
                                    },
                                  )),
                              Expanded(
                                  flex: 2,
                                  child: _buildEditableCell(
                                    controller:
                                        _currencyControllers[worker.name],
                                    focusNode: _currencyFocusNodes[worker.name],
                                    isNumeric: false,
                                    onSubmitted: (val) {
                                      FocusScope.of(context).requestFocus(
                                          _mobileFocusNodes[worker.name]);
                                    },
                                  )),
                              Expanded(
                                  flex: 3,
                                  child: _buildEditableCell(
                                    controller: _mobileControllers[worker.name],
                                    focusNode: _mobileFocusNodes[worker.name],
                                    isNumeric: true,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly
                                    ],
                                    onSubmitted: (val) {
                                      if (index < sortedEntries.length - 1) {
                                        final nextWorker =
                                            sortedEntries[index + 1].value;
                                        FocusScope.of(context).requestFocus(
                                            _balanceFocusNodes[
                                                nextWorker.name]);
                                      } else {
                                        FocusScope.of(context)
                                            .requestFocus(_addFocusNode);
                                      }
                                    },
                                  )),
                              Expanded(
                                  flex: 2,
                                  child: Center(
                                      child: Text(worker.startDate,
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.black)))),
                              SizedBox(
                                width: 30,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  iconSize: 18,
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () => _deleteWorker(worker),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableCell({
    required TextEditingController? controller,
    required FocusNode? focusNode,
    bool isNumeric = false,
    List<TextInputFormatter>? inputFormatters,
    Function(String)? onSubmitted,
  }) {
    if (controller == null || focusNode == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13),
        keyboardType: isNumeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        inputFormatters: inputFormatters,
        onSubmitted: onSubmitted,
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 2),
          border: UnderlineInputBorder(),
        ),
      ),
    );
  }
}
