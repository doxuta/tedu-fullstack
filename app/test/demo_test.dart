/// Kiểm thử chế độ DEMO — máy chủ giả trong bộ nhớ phải trả lời đúng
/// các route như server thật, và AppState phải vào/ra demo sạch sẽ.
library;

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tedu/core/api_client.dart';
import 'package:tedu/core/app_state.dart';
import 'package:tedu/core/demo_api.dart';
import 'package:tedu/data/models.dart';

String ymOf(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DemoApi — dữ liệu gieo sẵn', () {
    late DemoApi api;
    setUp(() => api = DemoApi());

    test('có 12 học sinh, 6 ca học, đủ trạng thái', () async {
      final s = await api.get('/students') as Map;
      final items = (s['items'] as List).cast<Map<String, dynamic>>();
      expect(items.length, 12);
      expect(items.where((x) => x['status'] == 'active').length, 10);
      expect(items.any((x) => x['status'] == 'paused'), true);
      expect(items.any((x) => x['status'] == 'stopped'), true);

      final c = await api.get('/classes') as Map;
      expect((c['items'] as List).length, 6);
    });

    test('mọi thứ trong tuần đều có ít nhất 1 ca (mở demo ngày nào cũng sống động)', () async {
      final c = await api.get('/classes') as Map;
      final covered = <int>{};
      for (final cl in (c['items'] as List)) {
        covered.addAll(((cl as Map)['days'] as List).cast<int>());
      }
      expect(covered, {0, 1, 2, 3, 4, 5, 6});
    });

    test('/stats/today: có ca hôm nay, ca sớm nhất đã điểm danh', () async {
      final t = await api.get('/stats/today') as Map;
      final items = (t['items'] as List).cast<Map<String, dynamic>>();
      expect(items, isNotEmpty);
      expect(items.first['attendanceTaken'], true);
    });

    test('/stats/month: fee = buổi × đơn giá, remaining = fee − paid', () async {
      final ym = ymOf(DateTime.now());
      final m = await api.get('/stats/month/$ym') as Map;
      final rows = (m['rows'] as List).cast<Map<String, dynamic>>();
      expect(rows.length, 12);
      var fee = 0, paid = 0, sessions = 0;
      for (final r in rows) {
        expect(r['fee'], (r['sessions'] as int) * (r['rate'] as int));
        expect(r['remaining'], (r['fee'] as int) - (r['paid'] as int));
        fee += r['fee'] as int;
        paid += r['paid'] as int;
        sessions += r['sessions'] as int;
      }
      final totals = m['totals'] as Map;
      expect(totals['fee'], fee);
      expect(totals['paid'], paid);
      expect(totals['sessions'], sessions);
      expect(sessions, greaterThan(0), reason: 'phải có buổi học trong tháng hiện tại');
      expect(paid, greaterThan(0), reason: 'có học sinh đã đóng tiền');
      expect(totals['remaining'], lessThan(fee), reason: 'không thể chưa thu đồng nào');
    });

    test('tháng trước gần như thu đủ (chỉ Đức Duy còn nợ)', () async {
      final now = DateTime.now();
      final m = await api.get('/stats/month/${ymOf(DateTime(now.year, now.month - 1, 15))}') as Map;
      final debtors = (m['rows'] as List)
          .cast<Map<String, dynamic>>()
          .where((r) => (r['remaining'] as int) > 0)
          .toList();
      expect(debtors.length, 1);
      expect(debtors.single['name'], 'Phạm Đức Duy');
    });

    test('thu tiền → remaining giảm đúng số vừa thu', () async {
      final ym = ymOf(DateTime.now());
      final before = await api.get('/stats/month/$ym') as Map;
      final row = ((before['rows'] as List).cast<Map<String, dynamic>>())
          .firstWhere((r) => (r['remaining'] as int) > 0);
      await api.post('/payments', {
        'id': 'test-pay-1', 'studentId': row['studentId'], 'month': ym,
        'amount': 100000, 'paidAt': '2026-01-01', 'method': 'Tiền mặt', 'note': '',
      });
      final after = await api.get('/stats/month/$ym') as Map;
      final row2 = ((after['rows'] as List).cast<Map<String, dynamic>>())
          .firstWhere((r) => r['studentId'] == row['studentId']);
      expect(row2['remaining'], (row['remaining'] as int) - 100000);
    });

    test('điểm danh: PUT ghi đè theo (ngày, ca) và stats phản ánh ngay', () async {
      final t = await api.get('/stats/today') as Map;
      final pending = ((t['items'] as List).cast<Map<String, dynamic>>())
          .where((x) => x['attendanceTaken'] == false)
          .toList();
      if (pending.isEmpty) return; // CN chỉ có 1 ca và đã điểm danh — bỏ qua
      final classId = pending.first['classId'] as String;
      final date = t['date'] as String;
      await api.put('/attendance/$date/$classId', {
        'records': [
          {'studentId': 'x1', 'status': 'present', 'note': ''},
        ],
        'note': 'ghi lần 1',
      });
      await api.put('/attendance/$date/$classId', {
        'records': [
          {'studentId': 'x1', 'status': 'late', 'note': 'kẹt xe'},
        ],
        'note': 'ghi lần 2',
      });
      final list = await api.get('/attendance?from=$date&to=$date&classId=$classId') as Map;
      final items = (list['items'] as List).cast<Map<String, dynamic>>();
      expect(items.length, 1, reason: 'upsert không được nhân đôi bản ghi');
      expect((items.single['records'] as List).single['status'], 'late');
      final t2 = await api.get('/stats/today') as Map;
      final now2 = ((t2['items'] as List).cast<Map<String, dynamic>>())
          .firstWhere((x) => x['classId'] == classId);
      expect(now2['attendanceTaken'], true);
    });

    test('bật "tính phí buổi vắng KP" qua PATCH /me → số buổi tính phí tăng', () async {
      final ym = ymOf(DateTime.now());
      final before = ((await api.get('/stats/month/$ym') as Map)['totals'] as Map)['sessions'] as int;
      await api.patch('/me', {'settings': {'chargeUnexcused': true}});
      final after = ((await api.get('/stats/month/$ym') as Map)['totals'] as Map)['sessions'] as int;
      expect(after, greaterThanOrEqualTo(before));
    });

    test('tài liệu: POST rồi GET /files/:id giải mã đúng nội dung', () async {
      final r = await api.post('/files', {
        'lessonId': null, 'name': 'ghi-chu.txt', 'mime': 'text/plain',
        'dataBase64': base64Encode(utf8.encode('Xin chào TEdu')),
      }) as Map;
      final id = (r['item'] as Map)['id'] as String;
      final f = await api.get('/files/$id') as Map;
      expect(utf8.decode(base64Decode((f['item'] as Map)['dataBase64'] as String)), 'Xin chào TEdu');
      // danh sách /files không được lộ dataBase64 (đúng như server thật)
      final list = await api.get('/files') as Map;
      expect(((list['items'] as List).first as Map).containsKey('dataBase64'), false);
    });

    test('xoá mềm: DELETE học sinh → biến mất khỏi danh sách', () async {
      final s = await api.get('/students') as Map;
      final id = ((s['items'] as List).first as Map)['id'] as String;
      await api.delete('/students/$id');
      final s2 = await api.get('/students') as Map;
      expect((s2['items'] as List).length, 11);
      expect((s2['items'] as List).any((x) => (x as Map)['id'] == id), false);
    });

    test('quản trị: có 4 tài khoản, khoá/mở qua PATCH', () async {
      final u = await api.get('/admin/users') as Map;
      final users = (u['items'] as List).cast<Map<String, dynamic>>();
      expect(users.length, 4);
      expect(users.any((x) => x['status'] == 'blocked'), true);
      final target = users.firstWhere((x) => x['status'] == 'active' && x['role'] != 'admin');
      await api.patch('/admin/users/${target['id']}', {'status': 'blocked'});
      final u2 = await api.get('/admin/users') as Map;
      final again = ((u2['items'] as List).cast<Map<String, dynamic>>())
          .firstWhere((x) => x['id'] == target['id']);
      expect(again['status'], 'blocked');
    });

    test('giáo án & điểm có sẵn, route lạ trả ApiException 404', () async {
      expect(((await api.get('/lessons') as Map)['items'] as List).length, 6);
      expect(((await api.get('/scores') as Map)['items'] as List).length, greaterThan(10));
      expect(
        () => api.get('/khong-ton-tai'),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)),
      );
    });
  });

  group('AppState — vào/ra demo', () {
    test('enterDemo nạp dữ liệu; logout thoát sạch; demoMode được nhớ lại', () async {
      SharedPreferences.setMockInitialValues({});
      final st = AppState.instance;
      await st.init();
      expect(st.isLoggedIn, false);

      await st.enterDemo();
      expect(st.demo, true);
      expect(st.isLoggedIn, true);
      expect(st.userName, 'Cô Mai');
      expect(st.userRole, 'admin');
      expect(st.students.length, 12);
      expect(st.classes.length, 6);
      expect(st.api, isA<DemoApi>());

      // demo không được ghi cache đè lên dữ liệu tài khoản thật
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('cache.students'), isNull);
      expect(prefs.getString('demoMode'), '1');

      // khởi động lại app (init mới) → tự vào lại demo
      await st.init();
      expect(st.demo, true);
      expect(st.students.length, 12);

      await st.logout();
      expect(st.demo, false);
      expect(st.isLoggedIn, false);
      expect(st.students, isEmpty);
      expect(prefs.getString('demoMode'), isNull);
      expect(st.api, isNot(isA<DemoApi>()));
    });

    test('thao tác trong demo đi trọn vòng AppState → DemoApi', () async {
      SharedPreferences.setMockInitialValues({});
      final st = AppState.instance;
      await st.init();
      await st.enterDemo();

      final before = st.students.length;
      final s = Student(id: genUuid(), name: 'Test Thêm Mới', rate: 100000);
      await st.saveStudent(s, isNew: true);
      expect(st.students.length, before + 1);
      await st.refreshAll(); // đọc lại từ DemoApi — phải còn nguyên
      expect(st.students.any((x) => x.name == 'Test Thêm Mới'), true);

      await st.deleteStudent(s.id);
      await st.refreshAll();
      expect(st.students.any((x) => x.name == 'Test Thêm Mới'), false);
      expect(st.pendingOps, isEmpty, reason: 'demo không bao giờ xếp hàng đợi offline');
      await st.logout();
    });
  });
}
