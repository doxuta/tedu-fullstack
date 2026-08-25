/// Trạng thái toàn app — singleton ChangeNotifier (không cần package ngoài).
/// Online-first + cache cục bộ (SharedPreferences) + hàng đợi thao tác offline.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io' show WebSocket;
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models.dart';
import 'api_client.dart';
import 'demo_api.dart';
import 'i18n.dart';

String genUuid() {
  final rnd = Random.secure();
  final b = List<int>.generate(16, (_) => rnd.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String h(int i) => b[i].toRadixString(16).padLeft(2, '0');
  return '${h(0)}${h(1)}${h(2)}${h(3)}-${h(4)}${h(5)}-${h(6)}${h(7)}-${h(8)}${h(9)}-${h(10)}${h(11)}${h(12)}${h(13)}${h(14)}${h(15)}';
}

class AppState extends ChangeNotifier {
  AppState._();
  static final AppState instance = AppState._();

  late SharedPreferences _prefs;
  late ApiClient api;

  String serverUrl = 'http://localhost:8787';
  String? userEmail;
  String? userName;
  String userRole = 'teacher';
  Map<String, dynamic> userSettings = {};
  bool isLoggedIn = false;
  bool online = true;
  bool demo = false; // chế độ xem thử — dữ liệu mẫu trong máy, không cần server

  List<Student> students = [];
  List<ClassModel> classes = [];
  List<Map<String, dynamic>> pendingOps = []; // hàng đợi offline

  WebSocket? _ws;
  Timer? _wsRetry;
  Timer? _wsDebounce;
  bool realtimeOn = false;
  int dataVersion = 0; // các màn nghe để tự tải lại

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    serverUrl = _prefs.getString('serverUrl') ?? serverUrl;
    L.lang = _prefs.getString('lang') ?? 'vi';
    if (_prefs.getString('demoMode') == '1') {
      await _activateDemo();
      return;
    }
    api = ApiClient(baseUrl: serverUrl)
      ..accessToken = _prefs.getString('accessToken')
      ..refreshToken = _prefs.getString('refreshToken')
      ..onTokensRotated = (a, r) {
        _prefs.setString('accessToken', a);
        _prefs.setString('refreshToken', r);
      }
      ..onSessionExpired = () async => logout(local: true);
    userEmail = _prefs.getString('userEmail');
    userName = _prefs.getString('userName');
    userRole = _prefs.getString('userRole') ?? 'teacher';
    try {
      final us = _prefs.getString('userSettings');
      if (us != null) userSettings = jsonDecode(us) as Map<String, dynamic>;
    } catch (_) {}
    isLoggedIn = api.accessToken != null;
    _loadCache();
    if (isLoggedIn) { refreshAll(); _connectWs(); }
  }

  /* ---------- chế độ demo (xem thử, không cần server) ---------- */
  Future<void> enterDemo() async {
    await _prefs.setString('demoMode', '1');
    await _activateDemo();
  }

  Future<void> _activateDemo() async {
    final demoApi = DemoApi();
    demo = true;
    online = true;
    api = demoApi;
    userEmail = 'mai.demo@tedu.vn';
    userName = 'Cô Mai';
    userRole = 'admin'; // để xem được cả màn Quản trị
    userSettings = Map.of(demoApi.settings);
    students = [];
    classes = [];
    pendingOps = [];
    isLoggedIn = true;
    notifyListeners();
    await refreshAll();
  }

  Future<void> exitDemo() async {
    await _prefs.remove('demoMode');
    demo = false;
    isLoggedIn = false;
    userEmail = null;
    userName = null;
    userRole = 'teacher';
    userSettings = {};
    students = [];
    classes = [];
    pendingOps = [];
    api = ApiClient(baseUrl: serverUrl)
      ..onTokensRotated = (a, r) {
        _prefs.setString('accessToken', a);
        _prefs.setString('refreshToken', r);
      }
      ..onSessionExpired = () async => logout(local: true);
    notifyListeners();
  }

  /* ---------- realtime (WebSocket) ---------- */
  void _connectWs() {
    if (demo || kIsWeb || !isLoggedIn || api.accessToken == null) return;
    _wsRetry?.cancel();
    final wsUrl = serverUrl.replaceFirst('http', 'ws');
    WebSocket.connect('$wsUrl/ws?token=${api.accessToken}').then((ws) {
      _ws = ws;
      realtimeOn = true;
      notifyListeners();
      ws.listen((msg) {
        try {
          final m = jsonDecode(msg as String) as Map<String, dynamic>;
          if (m['type'] == 'changed') {
            // gom nhiều thông báo liên tiếp thành 1 lần tải
            _wsDebounce?.cancel();
            _wsDebounce = Timer(const Duration(milliseconds: 400), () async {
              await refreshAll();
              dataVersion++;
              notifyListeners();
            });
          }
        } catch (_) {}
      }, onDone: _wsDropped, onError: (_) => _wsDropped());
    }).catchError((Object _) { _wsDropped(); });
  }

  void _wsDropped() {
    realtimeOn = false;
    _ws = null;
    notifyListeners();
    if (!isLoggedIn) return;
    _wsRetry?.cancel();
    _wsRetry = Timer(const Duration(seconds: 5), _connectWs);
  }

  /* ---------- phiên đăng nhập ---------- */
  Future<void> setServerUrl(String url) async {
    serverUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    api.baseUrl = serverUrl;
    await _prefs.setString('serverUrl', serverUrl);
    notifyListeners();
  }

  Future<void> _storeSession(Map<String, dynamic> data) async {
    api.accessToken = data['accessToken'] as String;
    api.refreshToken = data['refreshToken'] as String;
    final user = data['user'] as Map<String, dynamic>;
    userEmail = user['email'] as String;
    userName = (user['name'] ?? '') as String;
    userRole = (user['role'] ?? 'teacher') as String;
    userSettings = ((user['settings'] ?? {}) as Map).cast<String, dynamic>();
    await _prefs.setString('accessToken', api.accessToken!);
    await _prefs.setString('refreshToken', api.refreshToken!);
    await _prefs.setString('userEmail', userEmail!);
    await _prefs.setString('userName', userName!);
    await _prefs.setString('userRole', userRole);
    await _prefs.setString('userSettings', jsonEncode(userSettings));
    isLoggedIn = true;
    notifyListeners();
    await refreshAll();
    _connectWs();
  }

  Future<void> register(String email, String password, String name) async {
    final data = await api.post('/auth/register',
        {'email': email, 'password': password, 'name': name}, auth: false);
    await _storeSession(data as Map<String, dynamic>);
  }

  Future<void> login(String email, String password) async {
    final data = await api.post('/auth/login',
        {'email': email, 'password': password}, auth: false);
    await _storeSession(data as Map<String, dynamic>);
  }

  Future<void> logout({bool local = false}) async {
    if (demo) { await exitDemo(); return; }
    if (!local && api.refreshToken != null) {
      try { await api.post('/auth/logout', {'refreshToken': api.refreshToken!}); } catch (_) {}
    }
    try { _ws?.close(); } catch (_) {}
    _ws = null;
    _wsRetry?.cancel();
    realtimeOn = false;
    api.accessToken = null;
    api.refreshToken = null;
    isLoggedIn = false;
    students = [];
    classes = [];
    await _prefs.remove('accessToken');
    await _prefs.remove('refreshToken');
    notifyListeners();
  }

  /* ---------- cache & offline ---------- */
  void _loadCache() {
    try {
      final s = _prefs.getString('cache.students');
      if (s != null) {
        students = (jsonDecode(s) as List)
            .map((e) => Student.fromJson(e as Map<String, dynamic>)).toList();
      }
      final c = _prefs.getString('cache.classes');
      if (c != null) {
        classes = (jsonDecode(c) as List)
            .map((e) => ClassModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      final q = _prefs.getString('cache.pendingOps');
      if (q != null) {
        pendingOps = (jsonDecode(q) as List).cast<Map<String, dynamic>>();
      }
    } catch (_) {}
  }

  Future<void> _saveCache() async {
    if (demo) return; // dữ liệu demo không ghi đè cache của tài khoản thật
    await _prefs.setString('cache.students',
        jsonEncode(students.map((e) => e.toJson()).toList()));
    await _prefs.setString('cache.classes',
        jsonEncode(classes.map((e) => e.toJson()).toList()));
    await _prefs.setString('cache.pendingOps', jsonEncode(pendingOps));
  }

  /// Gọi API; nếu mất mạng thì xếp thao tác vào hàng đợi để đẩy lại sau.
  Future<bool> _call(Future<dynamic> Function() fn, Map<String, dynamic> op) async {
    try {
      await fn();
      online = true;
      return true;
    } on ApiException catch (e) {
      if (e.status == 0) {
        online = false;
        pendingOps.add(op);
        await _saveCache();
        notifyListeners();
        return false;
      }
      rethrow;
    }
  }

  Future<int> flushPending() async {
    var done = 0;
    while (pendingOps.isNotEmpty) {
      final op = pendingOps.first;
      try {
        final method = op['method'] as String;
        final path = op['path'] as String;
        final body = op['body'];
        switch (method) {
          case 'POST': await api.post(path, body as Object);
          case 'PUT': await api.put(path, body as Object);
          case 'PATCH': await api.patch(path, body as Object);
          case 'DELETE': await api.delete(path);
        }
        pendingOps.removeAt(0);
        done++;
      } on ApiException catch (e) {
        if (e.status == 0) break; // vẫn offline
        pendingOps.removeAt(0);   // lỗi nghiệp vụ → bỏ qua, không kẹt hàng đợi
      }
    }
    await _saveCache();
    if (done > 0) await refreshAll();
    return done;
  }

  /* ---------- dữ liệu ---------- */
  Future<void> refreshAll() async {
    try {
      final s = await api.get('/students');
      students = ((s as Map)['items'] as List)
          .map((e) => Student.fromJson(e as Map<String, dynamic>)).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      final c = await api.get('/classes');
      classes = ((c as Map)['items'] as List)
          .map((e) => ClassModel.fromJson(e as Map<String, dynamic>)).toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
      online = true;
      await _saveCache();
    } on ApiException catch (e) {
      if (e.status == 0) { online = false; } else { rethrow; }
    } finally {
      notifyListeners();
    }
  }

  Student? studentById(String id) {
    for (final s in students) { if (s.id == id) return s; }
    return null;
  }

  Future<void> saveStudent(Student s, {required bool isNew}) async {
    if (isNew) {
      students.add(s);
    } else {
      final i = students.indexWhere((x) => x.id == s.id);
      if (i >= 0) students[i] = s;
    }
    students.sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
    final body = s.toCreateBody();
    await _call(() => api.post('/students', body),
        {'method': 'POST', 'path': '/students', 'body': body});
    await _saveCache();
  }

  Future<void> deleteStudent(String id) async {
    students.removeWhere((x) => x.id == id);
    notifyListeners();
    await _call(() => api.delete('/students/$id'),
        {'method': 'DELETE', 'path': '/students/$id'});
    await _saveCache();
  }

  Future<void> saveClass(ClassModel c, {required bool isNew}) async {
    if (isNew) {
      classes.add(c);
    } else {
      final i = classes.indexWhere((x) => x.id == c.id);
      if (i >= 0) classes[i] = c;
    }
    notifyListeners();
    final body = c.toCreateBody();
    await _call(() => api.post('/classes', body),
        {'method': 'POST', 'path': '/classes', 'body': body});
    await _saveCache();
  }

  Future<void> deleteClass(String id) async {
    classes.removeWhere((x) => x.id == id);
    notifyListeners();
    await _call(() => api.delete('/classes/$id'),
        {'method': 'DELETE', 'path': '/classes/$id'});
    await _saveCache();
  }

  Future<void> saveAttendance(String date, String classId,
      List<AttRecord> records, String note) async {
    final body = {'records': records.map((r) => r.toJson()).toList(), 'note': note};
    await _call(() => api.put('/attendance/$date/$classId', body),
        {'method': 'PUT', 'path': '/attendance/$date/$classId', 'body': body});
  }

  Future<void> recordPayment(Payment p) async {
    final body = p.toCreateBody();
    await _call(() => api.post('/payments', body),
        {'method': 'POST', 'path': '/payments', 'body': body});
  }

  /* ---------- ngôn ngữ & cài đặt cá nhân ---------- */
  Future<void> setLang(String lang) async {
    L.lang = lang;
    await _prefs.setString('lang', lang);
    notifyListeners();
  }

  Future<void> saveUserSettings(Map<String, dynamic> patch) async {
    userSettings = {...userSettings, ...patch};
    if (!demo) await _prefs.setString('userSettings', jsonEncode(userSettings));
    notifyListeners();
    await _call(() => api.patch('/me', {'settings': userSettings}),
        {'method': 'PATCH', 'path': '/me', 'body': {'settings': userSettings}});
  }

  /* ---------- điểm & giáo án ---------- */
  Future<List<Map<String, dynamic>>> fetchList(String path) async {
    final r = await api.get(path);
    return ((r as Map)['items'] as List).cast<Map<String, dynamic>>();
  }

  Future<void> upsert(String path, Map<String, dynamic> body) async {
    await _call(() => api.post(path, body),
        {'method': 'POST', 'path': path, 'body': body});
  }

  Future<void> remove(String path) async {
    await _call(() => api.delete(path), {'method': 'DELETE', 'path': path});
  }
}
