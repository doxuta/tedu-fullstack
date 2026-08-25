/// HTTP client — Bearer token, tự refresh khi 401, lỗi chuẩn hoá.
library;

import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final int status;
  final String code;
  final String message;
  ApiException(this.status, this.code, this.message);
  @override
  String toString() => message;
}

class ApiClient {
  String baseUrl; // ví dụ http://localhost:8787
  String? accessToken;
  String? refreshToken;
  Future<void> Function()? onSessionExpired;
  void Function(String access, String refresh)? onTokensRotated;

  ApiClient({required this.baseUrl});

  Uri _u(String path) => Uri.parse('$baseUrl/api/v1$path');

  Map<String, String> _headers({bool auth = true}) => {
        'Content-Type': 'application/json',
        if (auth && accessToken != null) 'Authorization': 'Bearer $accessToken',
      };

  Future<dynamic> _send(String method, String path,
      {Object? body, bool auth = true, bool retried = false}) async {
    late http.Response res;
    final uri = _u(path);
    final encoded = body == null ? null : jsonEncode(body);
    try {
      switch (method) {
        case 'GET':
          res = await http.get(uri, headers: _headers(auth: auth));
        case 'POST':
          res = await http.post(uri, headers: _headers(auth: auth), body: encoded);
        case 'PUT':
          res = await http.put(uri, headers: _headers(auth: auth), body: encoded);
        case 'PATCH':
          res = await http.patch(uri, headers: _headers(auth: auth), body: encoded);
        case 'DELETE':
          res = await http.delete(uri, headers: _headers(auth: auth));
        default:
          throw ArgumentError(method);
      }
    } catch (e) {
      throw ApiException(0, 'network', 'Không kết nối được máy chủ ($baseUrl). Kiểm tra server & mạng.');
    }

    if (res.statusCode == 401 && auth && !retried && refreshToken != null) {
      final ok = await _tryRefresh();
      if (ok) return _send(method, path, body: body, auth: auth, retried: true);
      await onSessionExpired?.call();
    }

    final text = utf8.decode(res.bodyBytes);
    final data = text.isEmpty ? null : jsonDecode(text);
    if (res.statusCode >= 400) {
      final err = (data is Map && data['error'] is Map) ? data['error'] as Map : null;
      throw ApiException(res.statusCode, (err?['code'] ?? 'error') as String,
          (err?['message'] ?? 'Lỗi ${res.statusCode}') as String);
    }
    return data;
  }

  Future<bool> _tryRefresh() async {
    try {
      final res = await http.post(_u('/auth/refresh'),
          headers: _headers(auth: false),
          body: jsonEncode({'refreshToken': refreshToken}));
      if (res.statusCode != 200) return false;
      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      accessToken = data['accessToken'] as String;
      refreshToken = data['refreshToken'] as String;
      onTokensRotated?.call(accessToken!, refreshToken!);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<dynamic> get(String p) => _send('GET', p);
  Future<dynamic> post(String p, Object body, {bool auth = true}) =>
      _send('POST', p, body: body, auth: auth);
  Future<dynamic> put(String p, Object body) => _send('PUT', p, body: body);
  Future<dynamic> patch(String p, Object body) => _send('PATCH', p, body: body);
  Future<dynamic> delete(String p) => _send('DELETE', p);
}
