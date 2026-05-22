// lib/models/transaction.dart
enum TransactionType { withdrawal, return_ }

extension TransactionTypeExt on TransactionType {
  String get name {
    switch (this) {
      case TransactionType.withdrawal:
        return 'سحب';
      case TransactionType.return_:
        return 'إرجاع';
    }
  }
  
  String get code {
    switch (this) {
      case TransactionType.withdrawal:
        return 'withdrawal';
      case TransactionType.return_:
        return 'return';
    }
  }
  
  static TransactionType fromCode(String code) {
    if (code == 'withdrawal') return TransactionType.withdrawal;
    return TransactionType.return_;
  }
}

class Transaction {
  int id;
  int customerId;
  String materialName;
  TransactionType type;
  double quantity;
  double pricePerUnit;
  double discountPercent;
  String date;
  String? returnDate;      // تاريخ العودة المتوقع (للسحب فقط)
  String? actualReturnDate; // تاريخ الإرجاع الفعلي (جديد)
  String? note;
  int? linkedWithdrawalId;  // ربط الإرجاع بعملية السحب الأصلية

  Transaction({
    required this.id,
    required this.customerId,
    required this.materialName,
    required this.type,
    required this.quantity,
    required this.pricePerUnit,
    required this.discountPercent,
    required this.date,
    this.returnDate,
    this.actualReturnDate,
    this.note,
    this.linkedWithdrawalId,
  });

  double get totalBeforeDiscount => quantity * pricePerUnit;
  double get discountAmount => totalBeforeDiscount * (discountPercent / 100);
  double get totalAfterDiscount => totalBeforeDiscount - discountAmount;

  Map<String, dynamic> toJson() => {
    'id': id,
    'customerId': customerId,
    'materialName': materialName,
    'type': type.code,
    'quantity': quantity,
    'pricePerUnit': pricePerUnit,
    'discountPercent': discountPercent,
    'date': date,
    'returnDate': returnDate,
    'actualReturnDate': actualReturnDate,
    'note': note,
    'linkedWithdrawalId': linkedWithdrawalId,
  };

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      customerId: json['customerId'],
      materialName: json['materialName'],
      type: TransactionTypeExt.fromCode(json['type']),
      quantity: json['quantity'],
      pricePerUnit: json['pricePerUnit'],
      discountPercent: json['discountPercent'],
      date: json['date'],
      returnDate: json['returnDate'],
      actualReturnDate: json['actualReturnDate'],
      note: json['note'],
      linkedWithdrawalId: json['linkedWithdrawalId'],
    );
  }
}