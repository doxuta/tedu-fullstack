/// Trang quản trị — chỉ hiện khi tài khoản role=admin.
library;
import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import '../../core/api_client.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../widgets/vintage.dart';
import '../shell.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<Map<String, dynamic>> users = [];
  bool loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final items = await AppState.instance.fetchList('/admin/users');
      if (mounted) setState(() { users = items; loading = false; });
    } on ApiException catch (e) {
      if (mounted) { setState(() => loading = false); showToast(context, e.message); }
    }
  }

  Future<void> _toggle(Map<String, dynamic> u) async {
    final block = u['status'] != 'blocked';
    if (block) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(L.t('Khoá tài khoản?', 'Block account?', '계정 차단?')),
          content: Text('${u['email']}\n${L.t(
              'Bị khoá là không đăng nhập/đồng bộ được cho tới khi mở lại.',
              'They cannot sign in or sync until unblocked.', '해제 전까지 로그인 불가.')}'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(L.t('Huỷ', 'Cancel', '취소'))),
            TextButton(onPressed: () => Navigator.pop(c, true),
                child: Text(L.t('Khoá', 'Block', '차단'), style: const TextStyle(color: Ink2.oxblood))),
          ],
        ),
      );
      if (ok != true) return;
    }
    try {
      await AppState.instance.api.patch('/admin/users/${u['id']}',
          {'status': block ? 'blocked' : 'active'});
      _load();
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: teduBar(context, L.t('Quản trị', 'Admin', '관리자')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          if (loading) const LinearProgressIndicator(minHeight: 2),
          SectionLabel(L.t('Tài khoản đã đăng ký (${users.length})',
              'Registered accounts (${users.length})', '등록된 계정 (${users.length})')),
          for (final u in users)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PaperCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  InitialAvatar('${u['name'] ?? u['email']}'),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Flexible(child: Text('${u['email']}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700))),
                      const SizedBox(width: 6),
                      if (u['role'] == 'admin') const StampBadge('ADMIN', color: Ink2.navy),
                    ]),
                    Text('${u['name'] ?? ''} · ${u['studentCount']} ${L.t('học sinh', 'students', '학생')}',
                        style: const TextStyle(fontSize: 12, color: Ink2.muted)),
                  ])),
                  if (u['status'] == 'blocked')
                    const StampBadge('Bị khoá', color: Ink2.oxblood)
                  else
                    const StampBadge('Hoạt động'),
                  const SizedBox(width: 8),
                  if (u['id'] != null && u['email'] != AppState.instance.userEmail)
                    OutlinedButton(
                      onPressed: () => _toggle(u),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: u['status'] == 'blocked' ? Ink2.green : Ink2.oxblood,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                      child: Text(u['status'] == 'blocked'
                          ? L.t('Mở khoá', 'Unblock', '해제')
                          : L.t('Khoá', 'Block', '차단'),
                          style: const TextStyle(fontSize: 12)),
                    ),
                ]),
              ),
            ),
          const SizedBox(height: 8),
          Text(L.t(
              'Muốn thêm quản trị viên: thêm email vào biến môi trường ADMIN_EMAILS của server (phân cách bằng dấu phẩy) — người đó đăng nhập lại là thành admin.',
              'To add admins: put their email into the server ADMIN_EMAILS env (comma-separated); they become admin on next sign-in.',
              '관리자 추가: 서버 ADMIN_EMAILS 환경변수에 이메일 추가.'),
              style: const TextStyle(fontSize: 12, color: Ink2.muted, height: 1.5)),
        ]),
      ),
    );
  }
}
