class AttendanceRecord {
  String workerName;
  String wageDescription; // e.g., "7 دولار"
  String status; // "موجود" or "غائب"

  AttendanceRecord({
    required this.workerName,
    required this.wageDescription,
    required this.status,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      workerName: json['workerName'] ?? '',
      wageDescription: json['wageDescription'] ?? '',
      status: json['status'] ?? 'غائب',
    );
  }

  Map<String, dynamic> toJson() => {
        'workerName': workerName,
        'wageDescription': wageDescription,
        'status': status,
      };
}

class AttendanceDocument {
  final String date;
  final List<AttendanceRecord> records;

  AttendanceDocument({
    required this.date,
    required this.records,
  });

  factory AttendanceDocument.fromJson(Map<String, dynamic> json) {
    var recordsList = json['records'] as List;
    List<AttendanceRecord> records =
        recordsList.map((i) => AttendanceRecord.fromJson(i)).toList();
    return AttendanceDocument(
      date: json['date'] ?? '',
      records: records,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'records': records.map((r) => r.toJson()).toList(),
      };
}
