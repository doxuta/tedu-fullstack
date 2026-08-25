/// Model dữ liệu — phản chiếu schema server (server/src/db/schema.ts).
library;

class Student {
  final String id;
  String name, grade, subject, parentName, parentPhone, phone, note, status, startDate;
  int rate;
  bool deleted;
  String updatedAt;

  Student({
    required this.id, required this.name,
    this.grade = '', this.subject = '', this.rate = 0,
    this.parentName = '', this.parentPhone = '', this.phone = '',
    this.note = '', this.status = 'active', this.startDate = '',
    this.deleted = false, this.updatedAt = '',
  });

  factory Student.fromJson(Map<String, dynamic> j) => Student(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        grade: (j['grade'] ?? '') as String,
        subject: (j['subject'] ?? '') as String,
        rate: (j['rate'] ?? 0) as int,
        parentName: (j['parentName'] ?? '') as String,
        parentPhone: (j['parentPhone'] ?? '') as String,
        phone: (j['phone'] ?? '') as String,
        note: (j['note'] ?? '') as String,
        status: (j['status'] ?? 'active') as String,
        startDate: (j['startDate'] ?? '') as String,
        deleted: (j['deleted'] ?? false) as bool,
        updatedAt: (j['updatedAt'] ?? '') as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'grade': grade, 'subject': subject, 'rate': rate,
        'parentName': parentName, 'parentPhone': parentPhone, 'phone': phone,
        'note': note, 'status': status, 'startDate': startDate,
        'deleted': deleted, 'updatedAt': updatedAt,
      };

  Map<String, dynamic> toCreateBody() => {
        'id': id, 'name': name, 'grade': grade, 'subject': subject, 'rate': rate,
        'parentName': parentName, 'parentPhone': parentPhone, 'phone': phone,
        'note': note, 'status': status, 'startDate': startDate,
      };
}

class ClassModel {
  final String id;
  String name, subject, startTime, endTime, color, startDate, endDate;
  List<int> days;
  List<String> studentIds;
  bool deleted;
  String updatedAt;

  ClassModel({
    required this.id, required this.name,
    this.subject = '', this.days = const [],
    this.startTime = '18:00', this.endTime = '19:30',
    this.color = '#2F5D50', this.startDate = '', this.endDate = '',
    this.studentIds = const [], this.deleted = false, this.updatedAt = '',
  });

  factory ClassModel.fromJson(Map<String, dynamic> j) => ClassModel(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        subject: (j['subject'] ?? '') as String,
        days: ((j['days'] ?? []) as List).map((e) => (e as num).toInt()).toList(),
        startTime: (j['startTime'] ?? '18:00') as String,
        endTime: (j['endTime'] ?? '19:30') as String,
        color: (j['color'] ?? '#2F5D50') as String,
        startDate: (j['startDate'] ?? '') as String,
        endDate: (j['endDate'] ?? '') as String,
        studentIds: ((j['studentIds'] ?? []) as List).map((e) => e as String).toList(),
        deleted: (j['deleted'] ?? false) as bool,
        updatedAt: (j['updatedAt'] ?? '') as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'subject': subject, 'days': days,
        'startTime': startTime, 'endTime': endTime, 'color': color,
        'startDate': startDate, 'endDate': endDate, 'studentIds': studentIds,
        'deleted': deleted, 'updatedAt': updatedAt,
      };

  Map<String, dynamic> toCreateBody() => {
        'id': id, 'name': name, 'subject': subject, 'days': days,
        'startTime': startTime, 'endTime': endTime, 'color': color,
        'startDate': startDate, 'endDate': endDate, 'studentIds': studentIds,
      };
}

class AttRecord {
  final String studentId;
  String status; // present | late | excused | absent
  String note;
  AttRecord({required this.studentId, required this.status, this.note = ''});
  factory AttRecord.fromJson(Map<String, dynamic> j) => AttRecord(
        studentId: j['studentId'] as String,
        status: (j['status'] ?? 'present') as String,
        note: (j['note'] ?? '') as String,
      );
  Map<String, dynamic> toJson() => {'studentId': studentId, 'status': status, 'note': note};
}

class AttendanceEntry {
  final String id, date, classId;
  String note;
  List<AttRecord> records;
  AttendanceEntry({
    required this.id, required this.date, required this.classId,
    this.note = '', this.records = const [],
  });
  factory AttendanceEntry.fromJson(Map<String, dynamic> j) => AttendanceEntry(
        id: j['id'] as String,
        date: j['date'] as String,
        classId: j['classId'] as String,
        note: (j['note'] ?? '') as String,
        records: ((j['records'] ?? []) as List)
            .map((e) => AttRecord.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class Payment {
  final String id;
  String studentId, month, paidAt, method, note;
  int amount;
  Payment({
    required this.id, required this.studentId, required this.month,
    required this.amount, this.paidAt = '', this.method = 'Chuyển khoản', this.note = '',
  });
  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
        id: j['id'] as String,
        studentId: j['studentId'] as String,
        month: j['month'] as String,
        amount: (j['amount'] ?? 0) as int,
        paidAt: (j['paidAt'] ?? '') as String,
        method: (j['method'] ?? '') as String,
        note: (j['note'] ?? '') as String,
      );
  Map<String, dynamic> toCreateBody() => {
        'id': id, 'studentId': studentId, 'month': month, 'amount': amount,
        'paidAt': paidAt, 'method': method, 'note': note,
      };
}

class MonthStatRow {
  final String studentId, name;
  final int rate, sessions, fee, paid, remaining;
  MonthStatRow.fromJson(Map<String, dynamic> j)
      : studentId = j['studentId'] as String,
        name = j['name'] as String,
        rate = (j['rate'] ?? 0) as int,
        sessions = (j['sessions'] ?? 0) as int,
        fee = (j['fee'] ?? 0) as int,
        paid = (j['paid'] ?? 0) as int,
        remaining = (j['remaining'] ?? 0) as int;
}

class TodayClass {
  final String classId, name, subject, startTime, endTime, color;
  final int studentCount;
  final bool attendanceTaken;
  TodayClass.fromJson(Map<String, dynamic> j)
      : classId = j['classId'] as String,
        name = j['name'] as String,
        subject = (j['subject'] ?? '') as String,
        startTime = j['startTime'] as String,
        endTime = j['endTime'] as String,
        color = (j['color'] ?? '#2F5D50') as String,
        studentCount = (j['studentCount'] ?? 0) as int,
        attendanceTaken = (j['attendanceTaken'] ?? false) as bool;
}
