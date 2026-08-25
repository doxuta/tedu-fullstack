import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_state.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../widgets/vintage.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _server = TextEditingController(text: AppState.instance.serverUrl);
  bool _registering = false;
  bool _busy = false;
  bool _showServer = false;

  Future<void> _submit() async {
    final st = AppState.instance;
    setState(() => _busy = true);
    try {
      await st.setServerUrl(_server.text);
      if (_registering) {
        await st.register(_email.text.trim(), _password.text, _name.text.trim());
      } else {
        await st.login(_email.text.trim(), _password.text);
      }
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Ink2.espresso,
      body: Stack(children: [
        const Positioned.fill(child: Grain(opacity: .06)),
        // khung viền kép vàng đồng ôm cả màn hình — như hero bản web
        Positioned.fill(
          child: Container(
            margin: const EdgeInsets.all(14),
            decoration: BoxDecoration(border: Border.all(color: Ink2.gold.withValues(alpha: .8), width: 1.2)),
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(border: Border.all(color: Ink2.gold.withValues(alpha: .4), width: .8)),
            ),
          ),
        ),
        const Positioned(top: 34, right: 40, child: Postmark(size: 96)),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(34),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('TIỆM QUẢN LÝ DẠY HỌC · EST. 2026',
                    style: TextStyle(fontSize: 10, letterSpacing: 4,
                        color: Ink2.gold.withValues(alpha: .95), fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Text('TEdu',
                    style: GoogleFonts.playfairDisplay(fontSize: 84, height: 1,
                        fontWeight: FontWeight.w900, color: Ink2.cream)),
                const Handwritten('dành cho gia sư tận tâm', size: 22),
                const SizedBox(height: 30),
                PaperCard(
                  ornate: true,
                  padding: const EdgeInsets.fromLTRB(30, 26, 30, 22),
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(_registering ? 'MỞ SỔ MỚI' : 'MỞ SỔ CỦA BẠN',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11, letterSpacing: 3,
                              fontWeight: FontWeight.w800, color: Ink2.oxblood)),
                      const SizedBox(height: 18),
                      if (_registering) ...[
                        TextField(controller: _name,
                            decoration: const InputDecoration(labelText: 'Tên hiển thị')),
                        const SizedBox(height: 12),
                      ],
                      TextField(controller: _email,
                          keyboardType: TextInputType.emailAddress, autocorrect: false,
                          decoration: const InputDecoration(labelText: 'Email')),
                      const SizedBox(height: 12),
                      TextField(controller: _password, obscureText: true,
                          onSubmitted: (_) => _submit(),
                          decoration: const InputDecoration(labelText: 'Mật khẩu (≥ 8 ký tự)')),
                      const SizedBox(height: 20),
                      Center(child: LetterpressButton(
                        _busy ? 'Đang xử lý...' : (_registering ? 'Đăng ký' : 'Đăng nhập'),
                        onPressed: _busy ? null : _submit,
                      )),
                      TextButton(
                        onPressed: () => setState(() => _registering = !_registering),
                        child: Text(
                            _registering ? 'Đã có tài khoản? Đăng nhập' : 'Lần đầu dùng? Đăng ký — miễn phí',
                            style: const TextStyle(color: Ink2.oxblood, fontSize: 13)),
                      ),
                      const Fleuron(),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => setState(() => _showServer = !_showServer),
                        child: Text('⚙ Máy chủ: ${_server.text}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11, color: Ink2.muted)),
                      ),
                      if (_showServer) ...[
                        const SizedBox(height: 10),
                        TextField(controller: _server,
                            decoration: const InputDecoration(
                                labelText: 'Địa chỉ máy chủ',
                                helperText: 'Máy ảo Android dùng http://10.0.2.2:8787')),
                      ],
                    ]),
                ),
                const SizedBox(height: 16),
                Text('SỔ GHI CHÉP CẨN THẬN ❦ MỞ RA LÀ THẤY, ĐÓNG LẠI LÀ XONG',
                    style: TextStyle(fontSize: 9, letterSpacing: 2,
                        color: Ink2.cream.withValues(alpha: .45), fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}
