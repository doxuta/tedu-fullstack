/// Chế độ DEMO — máy chủ giả chạy ngay trong app, không cần mạng.
///
/// `DemoApi` kế thừa `ApiClient` và trả lời đúng các route REST của server thật
/// (`server/src/modules/*`) từ một kho dữ liệu trong bộ nhớ, đã gieo sẵn
/// dữ liệu mẫu tiếng Việt phong phú: 12 học sinh, 6 ca học, 8 tuần điểm danh,
/// học phí, điểm kiểm tra, giáo án, tài liệu... Mọi màn hình đều dùng được
/// và mọi thao tác thêm/sửa/xoá đều có hiệu lực trong phiên demo.
library;

import 'dart:convert';
import 'api_client.dart';

class DemoApi extends ApiClient {
  DemoApi() : super(baseUrl: 'demo://tedu') {
    accessToken = 'demo';
    _seed();
  }

  /* ══════════════════ Kho dữ liệu trong bộ nhớ ══════════════════ */

  final List<Map<String, dynamic>> _students = [];
  final List<Map<String, dynamic>> _classes = [];
  final List<Map<String, dynamic>> _attendance = []; // {id,date,classId,note,records:[{studentId,status,note}]}
  final List<Map<String, dynamic>> _payments = [];
  final List<Map<String, dynamic>> _scores = [];
  final List<Map<String, dynamic>> _lessons = [];
  final List<Map<String, dynamic>> _files = []; // + dataBase64
  final List<Map<String, dynamic>> _users = [];
  Map<String, dynamic> settings = {
    'chargeUnexcused': false,
    'bankId': 'VCB',
    'bankAcc': '0123456789',
    'bankHolder': 'NGUYEN THI MAI',
  };

  int _idSeq = 0;
  String _id() => 'demo-${(++_idSeq).toString().padLeft(4, '0')}';

  static String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /* ══════════════════ Gieo dữ liệu mẫu ══════════════════ */

  void _seed() {
    final now = DateTime.now();

    Map<String, dynamic> hs(String name, String grade, String subject, int rate,
            {String parent = '', String phone = '', String status = 'active', String note = ''}) =>
        {
          'id': _id(), 'name': name, 'grade': grade, 'subject': subject, 'rate': rate,
          'parentName': parent, 'parentPhone': phone, 'phone': '',
          'note': note, 'status': status,
          'startDate': _iso(now.subtract(const Duration(days: 120))),
          'deleted': false, 'updatedAt': now.toIso8601String(),
        };

    _students.addAll([
      hs('Nguyễn Minh Anh', 'Lớp 8A · THCS Lê Quý Đôn', 'Toán', 180000,
          parent: 'Chị Hằng', phone: '0903 555 111', note: 'Tiến bộ rõ từ tháng trước'),
      hs('Trần Gia Bảo', 'Lớp 9 · THCS Nguyễn Du', 'Toán', 200000,
          parent: 'Anh Tuấn', phone: '0908 222 333', note: 'Ôn thi vào 10'),
      hs('Lê Thảo Chi', 'Lớp 7B · THCS Chu Văn An', 'Ngữ văn', 150000,
          parent: 'Chị Loan', phone: '0912 444 555'),
      hs('Phạm Đức Duy', 'Lớp 12A1 · THPT Lê Hồng Phong', 'Vật lý', 250000,
          parent: 'Cô Thuý', phone: '0918 666 777', note: 'Mục tiêu 8+ thi THPT'),
      hs('Võ Thuỳ Dung', 'Lớp 10 · THPT Nguyễn Thị Minh Khai', 'Hoá học', 220000,
          parent: 'Anh Phong', phone: '0933 888 999'),
      hs('Hoàng Nhật Huy', 'Lớp 8A · THCS Lê Quý Đôn', 'Toán', 180000,
          parent: 'Chị Vân', phone: '0977 111 222'),
      hs('Đặng Khánh Linh', 'Lớp 9 · THCS Trần Văn Ơn', 'Tiếng Anh', 200000,
          parent: 'Chị Nga', phone: '0966 333 444', note: 'Chuẩn bị IELTS junior'),
      hs('Bùi Tuấn Kiệt', 'Lớp 6 · THCS Colette', 'Toán', 140000,
          parent: 'Anh Khoa', phone: '0944 555 666'),
      hs('Đỗ Mai Phương', 'Lớp 11A2 · THPT Bùi Thị Xuân', 'Hoá học', 230000,
          parent: 'Cô Hạnh', phone: '0922 777 888'),
      hs('Ngô Thanh Sơn', 'Lớp 12 · THPT Marie Curie', 'Vật lý', 250000,
          parent: 'Anh Dũng', phone: '0955 999 000'),
      hs('Vũ Hà Trang', 'Lớp 7 · THCS Võ Trường Toản', 'Tiếng Anh', 160000,
          parent: 'Chị Mai', phone: '0988 123 456', status: 'paused', note: 'Nghỉ hè 1 tháng'),
      hs('Lý Quốc Việt', 'Lớp 9 · THCS Lê Lợi', 'Toán', 200000,
          parent: 'Anh Hải', phone: '0909 654 321', status: 'stopped', note: 'Đã thi xong'),
    ]);

    String sid(int i) => _students[i]['id'] as String;

    Map<String, dynamic> ca(String name, String subject, List<int> days,
            String start, String end, String color, List<String> ids) =>
        {
          'id': _id(), 'name': name, 'subject': subject, 'days': days,
          'startTime': start, 'endTime': end, 'color': color,
          'startDate': _iso(now.subtract(const Duration(days: 120))), 'endDate': '',
          'studentIds': ids, 'deleted': false, 'updatedAt': now.toIso8601String(),
        };

    // Phủ đủ 7 thứ trong tuần → mở demo ngày nào cũng có ca dạy.
    _classes.addAll([
      ca('Toán 8 nâng cao', 'Toán', [1, 3, 5], '18:00', '19:30', '#2F5D50', [sid(0), sid(5), sid(7)]),
      ca('Toán 9 luyện thi vào 10', 'Toán', [2, 4, 6], '18:00', '19:30', '#33506B', [sid(1), sid(6)]),
      ca('Văn 7 — đọc hiểu & viết', 'Ngữ văn', [0, 3], '08:00', '09:30', '#9A3B2E', [sid(2), sid(10)]),
      ca('Lý 12 tăng tốc', 'Vật lý', [2, 5], '19:45', '21:15', '#6B8E23', [sid(3), sid(9)]),
      ca('Hoá 10–11', 'Hoá học', [1, 4], '19:45', '21:15', '#C8922A', [sid(4), sid(8)]),
      ca('Anh văn giao tiếp', 'Tiếng Anh', [6], '09:00', '10:30', '#3E7C7B', [sid(6), sid(8), sid(10)]),
    ]);

    // Điểm danh 8 tuần gần nhất (đến hôm qua) — trạng thái giả lập tự nhiên.
    for (var back = 56; back >= 1; back--) {
      final day = now.subtract(Duration(days: back));
      final dow = day.weekday % 7;
      for (final c in _classes) {
        if (!(c['days'] as List).contains(dow)) continue;
        final records = <Map<String, dynamic>>[];
        var idx = 0;
        for (final stuId in (c['studentIds'] as List)) {
          final roll = (day.day * 7 + day.month * 3 + idx * 11) % 20;
          final status = roll == 18 ? 'late' : roll == 19 ? 'excused' : roll == 17 ? 'absent' : 'present';
          records.add({'studentId': stuId, 'status': status, 'note': ''});
          idx++;
        }
        _attendance.add({
          'id': _id(), 'date': _iso(day), 'classId': c['id'],
          'note': '', 'records': records, 'deleted': false,
        });
      }
    }
    // Hôm nay: ca sớm nhất đã điểm danh, các ca còn lại chờ — dashboard có đủ 2 trạng thái.
    final todayDow = now.weekday % 7;
    final todays = _classes.where((c) => (c['days'] as List).contains(todayDow)).toList()
      ..sort((a, b) => (a['startTime'] as String).compareTo(b['startTime'] as String));
    if (todays.isNotEmpty) {
      final c = todays.first;
      _attendance.add({
        'id': _id(), 'date': _iso(now), 'classId': c['id'], 'note': '',
        'records': [
          for (final stuId in (c['studentIds'] as List))
            {'studentId': stuId, 'status': 'present', 'note': ''},
        ],
        'deleted': false,
      });
    }

    // Học phí: tháng trước thu đủ gần hết; tháng này thu một phần — có đủ 3 trạng thái.
    final thisYm = _iso(now).substring(0, 7);
    final prev = DateTime(now.year, now.month - 1, 15);
    final prevYm = _iso(prev).substring(0, 7);
    void pay(String stuId, String ym, int amount, int daysAgo, String method) =>
        _payments.add({
          'id': _id(), 'studentId': stuId, 'month': ym, 'amount': amount,
          'paidAt': _iso(now.subtract(Duration(days: daysAgo))),
          'method': method, 'note': '', 'deleted': false,
        });
    for (var i = 0; i < _students.length; i++) {
      final feePrev = _sessionsOf(sid(i), prevYm) * (_students[i]['rate'] as int);
      if (feePrev <= 0) continue;
      if (i == 3) {
        pay(sid(i), prevYm, feePrev ~/ 2, 20, 'Tiền mặt'); // Đức Duy còn nợ tháng trước
      } else {
        pay(sid(i), prevYm, feePrev, 25 + i, i.isEven ? 'Chuyển khoản' : 'Tiền mặt');
      }
    }
    final feeNow0 = _sessionsOf(sid(0), thisYm) * (_students[0]['rate'] as int);
    if (feeNow0 > 0) pay(sid(0), thisYm, feeNow0, 2, 'Chuyển khoản'); // Minh Anh đã đóng đủ
    final feeNow4 = _sessionsOf(sid(4), thisYm) * (_students[4]['rate'] as int);
    if (feeNow4 > 200000) pay(sid(4), thisYm, feeNow4 - 200000, 1, 'Tiền mặt'); // Thuỳ Dung đóng thiếu
    // Đầu tháng (chưa em nào kịp đóng) → vẫn đảm bảo có ít nhất 1 khoản thu trong tháng.
    if (!_payments.any((p) => p['month'] == thisYm)) {
      for (var i = 0; i < _students.length; i++) {
        final fee = _sessionsOf(sid(i), thisYm) * (_students[i]['rate'] as int);
        if (fee > 0) { pay(sid(i), thisYm, fee, 0, 'Chuyển khoản'); break; }
      }
    }

    // Điểm kiểm tra — Minh Anh có chuỗi điểm đi lên để biểu đồ đẹp.
    void diem(int stu, double score, String title, int daysAgo, [String note = '']) =>
        _scores.add({
          'id': _id(), 'studentId': sid(stu), 'score': score, 'title': title,
          'date': _iso(now.subtract(Duration(days: daysAgo))), 'note': note, 'deleted': false,
        });
    diem(0, 6.5, 'KT 15 phút — hằng đẳng thức', 52);
    diem(0, 7.0, 'KT 1 tiết giữa kỳ', 38, 'Sai 1 câu vận dụng');
    diem(0, 7.5, 'KT 15 phút — phân tích đa thức', 24);
    diem(0, 8.0, 'Đề ôn chương III', 14, 'Trình bày tiến bộ');
    diem(0, 8.5, 'KT 1 tiết chương III', 7, 'Khá chắc phần hình');
    diem(0, 9.0, 'Đề tổng hợp tháng', 1, 'Xuất sắc ✦');
    diem(1, 8.0, 'Đề thi thử vào 10 — lần 1', 30);
    diem(1, 6.5, 'Đề thi thử vào 10 — lần 2', 16, 'Mất điểm câu hình cuối');
    diem(1, 7.5, 'Đề thi thử vào 10 — lần 3', 5);
    diem(3, 7.0, 'Chuyên đề dao động cơ', 21);
    diem(3, 8.5, 'Chuyên đề sóng ánh sáng', 9, 'Tốt hơn hẳn');
    diem(2, 8.0, 'Viết đoạn nghị luận xã hội', 12, 'Diễn đạt mượt');
    diem(4, 6.0, 'KT chương este', 18, 'Cần ôn lại danh pháp');
    diem(4, 7.5, 'KT lại chương este', 4, 'Đã vững hơn');
    diem(6, 9.0, 'Mock test — Listening', 10);
    diem(8, 8.0, 'KT cân bằng hoá học', 6);

    // Giáo án + tài liệu đính kèm.
    String cid(int i) => _classes[i]['id'] as String;
    void ga(String title, String? classId, String content, String homework, int daysAgo) =>
        _lessons.add({
          'id': _id(), 'title': title, 'classId': classId, 'content': content,
          'homework': homework, 'date': _iso(now.subtract(Duration(days: daysAgo))),
          'deleted': false,
        });
    ga('Hằng đẳng thức đáng nhớ (tiết 2)', cid(0),
        'Ôn 7 hằng đẳng thức qua trò chơi ghép thẻ. Chữa bài 31–35 SBT.\nLưu ý Kiệt hay nhầm dấu khi khai triển (a−b)³.',
        'Phiếu số 4, bài 1–8. Học thuộc bảng hằng đẳng thức.', 2);
    ga('Đề thi thử vào 10 — chữa lần 3', cid(1),
        'Chữa trọn đề lần 3: đại 7đ, hình 3đ. Gia Bảo cần cẩn thận bước đặt điều kiện.',
        'Làm lại câu hình cuối + đề ôn số 12.', 3);
    ga('Nghị luận xã hội về lòng biết ơn', cid(2),
        'Phân tích dàn ý 3 phần, luyện mở bài gián tiếp. Đọc mẫu 2 đoạn hay.',
        'Viết hoàn chỉnh đoạn 200 chữ.', 5);
    ga('Chuyên đề: giao thoa ánh sáng', cid(3),
        'Công thức vân sáng/vân tối, bài tập khoảng vân. Duy tiếp thu nhanh, Sơn cần bổ trợ phần đổi đơn vị.',
        'Bài 1–12 chuyên đề 5.', 4);
    ga('Tốc độ phản ứng & cân bằng', cid(4),
        'Thí nghiệm mô phỏng ảnh hưởng nhiệt độ. Nhấn mạnh nguyên lý Lơ Sa-tơ-li-ê.',
        'Sơ đồ tư duy chương + 10 câu trắc nghiệm.', 6);
    ga('Small talk: hobbies & weekend', cid(5),
        'Luyện hội thoại cặp đôi, 12 cụm động từ chủ đề sở thích. Cả lớp nói tự tin hơn tuần trước.',
        'Quay video 1 phút tự giới thiệu sở thích.', 1);

    final deCuong = base64Encode(utf8.encode(
        'ĐỀ CƯƠNG ÔN TẬP — TOÁN 8 (demo)\n\n1. Hằng đẳng thức đáng nhớ\n2. Phân tích đa thức thành nhân tử\n3. Bài tập vận dụng 1–20\n\n❦ TEdu — tài liệu mẫu của chế độ demo.'));
    _files.addAll([
      {
        'id': _id(), 'lessonId': _lessons[0]['id'], 'name': 'de-cuong-on-tap-toan8.txt',
        'mime': 'text/plain', 'size': 220, 'createdAt': now.toIso8601String(),
        'dataBase64': deCuong, 'deleted': false,
      },
      {
        'id': _id(), 'lessonId': _lessons[1]['id'], 'name': 'dap-an-de-thi-thu-lan3.txt',
        'mime': 'text/plain', 'size': 180, 'createdAt': now.toIso8601String(),
        'dataBase64': base64Encode(utf8.encode('ĐÁP ÁN ĐỀ THI THỬ LẦN 3 (demo)\nCâu 1: x = 3; Câu 2: ...\n❦ TEdu demo.')),
        'deleted': false,
      },
    ]);

    // Danh sách tài khoản cho màn Quản trị (demo là admin).
    _users.addAll([
      {'id': _id(), 'email': 'mai.demo@tedu.vn', 'name': 'Cô Mai (bạn)', 'role': 'admin', 'status': 'active', 'studentCount': _students.length},
      {'id': _id(), 'email': 'lan.gv@tedu.vn', 'name': 'Cô Lan', 'role': 'teacher', 'status': 'active', 'studentCount': 8},
      {'id': _id(), 'email': 'hung.gv@tedu.vn', 'name': 'Thầy Hùng', 'role': 'teacher', 'status': 'blocked', 'studentCount': 3},
      {'id': _id(), 'email': 'thu.gv@tedu.vn', 'name': 'Cô Thu', 'role': 'teacher', 'status': 'active', 'studentCount': 15},
    ]);
  }

  /* ══════════════════ Nghiệp vụ dùng chung ══════════════════ */

  List<String> get _billable => settings['chargeUnexcused'] == true
      ? const ['present', 'late', 'absent']
      : const ['present', 'late'];

  int _sessionsOf(String studentId, String ym) {
    var n = 0;
    for (final a in _attendance) {
      if (a['deleted'] == true) continue;
      if (!(a['date'] as String).startsWith(ym)) continue;
      for (final r in (a['records'] as List)) {
        if (r['studentId'] == studentId && _billable.contains(r['status'])) n++;
      }
    }
    return n;
  }

  Map<String, dynamic> _monthStats(String ym) {
    final rows = <Map<String, dynamic>>[];
    for (final s in _students.where((x) => x['deleted'] != true)) {
      final sessions = _sessionsOf(s['id'] as String, ym);
      final fee = sessions * (s['rate'] as int);
      final paid = _payments
          .where((p) => p['deleted'] != true && p['studentId'] == s['id'] && p['month'] == ym)
          .fold<int>(0, (t, p) => t + (p['amount'] as int));
      rows.add({
        'studentId': s['id'], 'name': s['name'], 'rate': s['rate'],
        'sessions': sessions, 'fee': fee, 'paid': paid, 'remaining': fee - paid,
      });
    }
    final totals = {
      'sessions': rows.fold<int>(0, (t, r) => t + (r['sessions'] as int)),
      'fee': rows.fold<int>(0, (t, r) => t + (r['fee'] as int)),
      'paid': rows.fold<int>(0, (t, r) => t + (r['paid'] as int)),
      'remaining': rows.fold<int>(0, (t, r) => t + (r['remaining'] as int)),
    };
    return {'month': ym, 'chargeUnexcused': settings['chargeUnexcused'] == true, 'rows': rows, 'totals': totals};
  }

  Map<String, dynamic> _todayStats(String date) {
    final dow = DateTime.parse(date).weekday % 7;
    final items = _classes
        .where((c) => c['deleted'] != true && (c['days'] as List).contains(dow))
        .where((c) {
          final sd = (c['startDate'] ?? '') as String;
          final ed = (c['endDate'] ?? '') as String;
          return (sd.isEmpty || sd.compareTo(date) <= 0) && (ed.isEmpty || date.compareTo(ed) <= 0);
        })
        .toList()
      ..sort((a, b) => (a['startTime'] as String).compareTo(b['startTime'] as String));
    return {
      'date': date,
      'items': [
        for (final c in items)
          {
            'classId': c['id'], 'name': c['name'], 'subject': c['subject'],
            'startTime': c['startTime'], 'endTime': c['endTime'], 'color': c['color'],
            'studentCount': (c['studentIds'] as List).length,
            'attendanceTaken': _attendance.any((a) =>
                a['deleted'] != true && a['date'] == date && a['classId'] == c['id']),
          },
      ],
    };
  }

  /* ══════════════════ Bộ định tuyến REST ══════════════════ */

  static const _lag = Duration(milliseconds: 60); // cảm giác "gọi mạng" nhẹ

  List<Map<String, dynamic>> _live(List<Map<String, dynamic>> src) =>
      src.where((x) => x['deleted'] != true).toList();

  Map<String, dynamic> _clean(Map<String, dynamic> x) =>
      Map.of(x)..remove('deleted')..remove('dataBase64');

  Never _notFound(String what) => throw ApiException(404, 'not_found', 'Không tìm thấy $what (demo)');

  @override
  Future<dynamic> get(String p) async {
    await Future<void>.delayed(_lag);
    final uri = Uri.parse('demo://x$p');
    final seg = uri.pathSegments;
    final path = uri.path;

    if (path == '/students') return {'items': _live(_students).map(_clean).toList()};
    if (path == '/classes') return {'items': _live(_classes).map(_clean).toList()};
    if (path == '/scores') return {'items': _live(_scores).map(_clean).toList()};
    if (path == '/lessons') return {'items': _live(_lessons).map(_clean).toList()};
    if (path == '/files') return {'items': _live(_files).map(_clean).toList()};
    if (path == '/admin/users') return {'items': List.of(_users)};

    if (path == '/attendance') {
      final from = uri.queryParameters['from'] ?? '0000';
      final to = uri.queryParameters['to'] ?? '9999';
      final classId = uri.queryParameters['classId'];
      final items = _live(_attendance).where((a) {
        final d = a['date'] as String;
        if (d.compareTo(from) < 0 || d.compareTo(to) > 0) return false;
        if (classId != null && a['classId'] != classId) return false;
        return true;
      }).map(_clean).toList();
      return {'items': items};
    }

    if (seg.length == 2 && seg[0] == 'files') {
      final f = _files.firstWhere((x) => x['id'] == seg[1] && x['deleted'] != true,
          orElse: () => _notFound('tài liệu'));
      return {'item': Map.of(f)..remove('deleted')};
    }
    if (path == '/stats/today') {
      return _todayStats(uri.queryParameters['date'] ?? _iso(DateTime.now()));
    }
    if (seg.length == 3 && seg[0] == 'stats' && seg[1] == 'month') return _monthStats(seg[2]);

    _notFound(path);
  }

  void _upsert(List<Map<String, dynamic>> list, Map<String, dynamic> body) {
    final i = list.indexWhere((x) => x['id'] == body['id']);
    final row = {...body, 'deleted': false, 'updatedAt': DateTime.now().toIso8601String()};
    if (i >= 0) {
      list[i] = {...list[i], ...row};
    } else {
      list.add(row);
    }
  }

  @override
  Future<dynamic> post(String p, Object body, {bool auth = true}) async {
    await Future<void>.delayed(_lag);
    final b = (body as Map).cast<String, dynamic>();
    switch (p) {
      case '/students': _upsert(_students, b); return {'item': b};
      case '/classes': _upsert(_classes, b); return {'item': b};
      case '/payments': _upsert(_payments, b); return {'item': b};
      case '/scores': _upsert(_scores, b); return {'item': b};
      case '/lessons': _upsert(_lessons, b); return {'item': b};
      case '/files':
        final size = ((b['dataBase64'] as String? ?? '').length * 3) ~/ 4;
        if (size > 15 * 1024 * 1024) {
          throw ApiException(400, 'too_large', 'File quá lớn (tối đa 15MB)');
        }
        final row = {
          'id': _id(), 'lessonId': b['lessonId'], 'name': b['name'],
          'mime': b['mime'] ?? 'application/octet-stream', 'size': size,
          'createdAt': DateTime.now().toIso8601String(),
          'dataBase64': b['dataBase64'], 'deleted': false,
        };
        _files.add(row);
        return {'item': {'id': row['id'], 'name': row['name'], 'size': size, 'lessonId': row['lessonId']}};
      case '/auth/logout': return {'ok': true};
    }
    _notFound(p);
  }

  @override
  Future<dynamic> put(String p, Object body) async {
    await Future<void>.delayed(_lag);
    final seg = Uri.parse('demo://x$p').pathSegments;
    if (seg.length == 3 && seg[0] == 'attendance') {
      final date = seg[1], classId = seg[2];
      final b = (body as Map).cast<String, dynamic>();
      final i = _attendance.indexWhere(
          (a) => a['date'] == date && a['classId'] == classId && a['deleted'] != true);
      final row = {
        'id': i >= 0 ? _attendance[i]['id'] : _id(),
        'date': date, 'classId': classId,
        'note': b['note'] ?? '', 'records': b['records'] ?? [], 'deleted': false,
      };
      if (i >= 0) {
        _attendance[i] = row;
      } else {
        _attendance.add(row);
      }
      return {'item': Map.of(row)..remove('deleted')};
    }
    _notFound(p);
  }

  @override
  Future<dynamic> patch(String p, Object body) async {
    await Future<void>.delayed(_lag);
    final b = (body as Map).cast<String, dynamic>();
    if (p == '/me') {
      if (b['settings'] is Map) {
        settings = {...settings, ...(b['settings'] as Map).cast<String, dynamic>()};
      }
      return {'item': {'settings': settings}};
    }
    final seg = Uri.parse('demo://x$p').pathSegments;
    if (seg.length == 3 && seg[0] == 'admin' && seg[1] == 'users') {
      final i = _users.indexWhere((u) => u['id'] == seg[2]);
      if (i < 0) _notFound('tài khoản');
      _users[i] = {..._users[i], 'status': b['status'] ?? _users[i]['status']};
      return {'item': _users[i]};
    }
    _notFound(p);
  }

  @override
  Future<dynamic> delete(String p) async {
    await Future<void>.delayed(_lag);
    final seg = Uri.parse('demo://x$p').pathSegments;
    if (seg.length != 2) _notFound(p);
    final list = switch (seg[0]) {
      'students' => _students,
      'classes' => _classes,
      'scores' => _scores,
      'lessons' => _lessons,
      'files' => _files,
      'payments' => _payments,
      _ => null,
    };
    if (list == null) _notFound(p);
    final i = list.indexWhere((x) => x['id'] == seg[1]);
    if (i >= 0) list[i] = {...list[i], 'deleted': true};
    return {'ok': true};
  }
}
