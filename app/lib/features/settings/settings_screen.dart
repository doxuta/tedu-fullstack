import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../widgets/vintage.dart';
import '../shell.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final bankId = TextEditingController(text: '${AppState.instance.userSettings['bankId'] ?? ''}');
  late final bankAcc = TextEditingController(text: '${AppState.instance.userSettings['bankAcc'] ?? ''}');
  late final bankHolder = TextEditingController(text: '${AppState.instance.userSettings['bankHolder'] ?? ''}');
  late final geminiKey = TextEditingController(text: '${AppState.instance.userSettings['geminiKey'] ?? ''}');
  late bool chargeUnexcused = AppState.instance.userSettings['chargeUnexcused'] == true;

  @override
  Widget build(BuildContext context) {
    final st = AppState.instance;
    return Scaffold(
      appBar: teduBar(context, L.t('Cài đặt', 'Settings', '설정')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        PaperCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionLabel(L.t('Tài khoản', 'Account', '계정')),
            DottedRow(L.t('Tên', 'Name', '이름'), Text(st.userName ?? '')),
            const SizedBox(height: 2),
            DottedRow('Email', Text(st.userEmail ?? '')),
            const SizedBox(height: 2),
            DottedRow(L.t('Máy chủ', 'Server', '서버'),
                Text(st.demo ? L.t('Bản demo — dữ liệu mẫu trong máy', 'Demo — sample data on device', '데모 — 샘플 데이터')
                    : st.serverUrl,
                    style: const TextStyle(fontSize: 12))),
            const SizedBox(height: 12),
            Wrap(spacing: 10, runSpacing: 8, children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.sync, size: 17),
                label: Text(L.t('Tải lại dữ liệu', 'Reload data', '새로고침')),
                onPressed: () async {
                  await st.refreshAll();
                  if (context.mounted) {
                    showToast(context, st.online
                        ? L.t('Đã tải lại', 'Reloaded', '새로고침 완료')
                        : L.t('Đang offline — dùng bản cache', 'Offline — using cache', '오프라인'));
                  }
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.logout, size: 17),
                label: Text(st.demo
                    ? L.t('Thoát bản demo', 'Exit demo', '데모 종료')
                    : L.t('Đăng xuất', 'Sign out', '로그아웃')),
                style: OutlinedButton.styleFrom(foregroundColor: Ink2.oxblood),
                onPressed: () => st.logout(),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 14),
        PaperCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionLabel(L.t('Ngôn ngữ', 'Language', '언어')),
            Wrap(spacing: 8, children: [
              for (final (code, label) in const [('vi', 'Tiếng Việt'), ('en', 'English'), ('ko', '한국어')])
                ChoiceChip(
                  label: Text(label),
                  selected: L.lang == code,
                  selectedColor: Ink2.panel,
                  onSelected: (_) => st.setLang(code),
                ),
            ]),
          ]),
        ),
        const SizedBox(height: 14),
        PaperCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionLabel(L.t('Học phí', 'Tuition', '수업료')),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(L.t('Tính phí cả buổi vắng không phép', 'Bill unexcused absences too', '무단 결석도 청구'),
                  style: const TextStyle(fontSize: 14)),
              value: chargeUnexcused,
              activeTrackColor: Ink2.green,
              onChanged: (v) {
                setState(() => chargeUnexcused = v);
                st.saveUserSettings({'chargeUnexcused': v});
              },
            ),
          ]),
        ),
        const SizedBox(height: 14),
        PaperCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionLabel(L.t('Thanh toán & phiếu học phí (VietQR)', 'Payment & receipts (VietQR)', '결제·영수증 (VietQR)')),
            Row(children: [
              Expanded(child: TextField(controller: bankId,
                  decoration: const InputDecoration(labelText: 'Mã ngân hàng (BIDV, VCB, TCB...)'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: bankAcc,
                  decoration: const InputDecoration(labelText: 'Số tài khoản'))),
            ]),
            const SizedBox(height: 10),
            TextField(controller: bankHolder,
                decoration: const InputDecoration(labelText: 'Tên chủ tài khoản (IN HOA KHÔNG DẤU)')),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                await st.saveUserSettings({
                  'bankId': bankId.text.trim().toUpperCase(),
                  'bankAcc': bankAcc.text.trim(),
                  'bankHolder': bankHolder.text.trim(),
                });
                if (context.mounted) showToast(context, L.t('Đã lưu — phiếu học phí sẽ tự sinh VietQR', 'Saved', '저장됨'));
              },
              child: Text(L.t('LƯU THÔNG TIN', 'SAVE', '저장')),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        PaperCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionLabel(L.t('Trợ lý AI (Gemini)', 'AI Assistant (Gemini)', 'AI 비서 (Gemini)')),
            TextField(controller: geminiKey, obscureText: true,
                decoration: const InputDecoration(labelText: 'Khoá API Gemini (miễn phí)', hintText: 'AIza...')),
            const SizedBox(height: 8),
            Text(L.t(
                'Lấy khoá ~1 phút tại aistudio.google.com/app/apikey → dán vào đây. Không có khoá vẫn dùng được bộ lệnh cơ bản.',
                'Get a free key at aistudio.google.com/app/apikey. Basic commands work without one.',
                'aistudio.google.com/app/apikey 에서 무료 키 발급.'),
                style: const TextStyle(fontSize: 12, color: Ink2.muted, height: 1.5)),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                await st.saveUserSettings({'geminiKey': geminiKey.text.trim()});
                if (context.mounted) showToast(context, L.t('Đã lưu khoá', 'Key saved', '키 저장됨'));
              },
              child: Text(L.t('LƯU KHOÁ', 'SAVE KEY', '키 저장')),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        const PaperCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionLabel('TEdu'),
            Text('TEdu ✳ Sổ quản lý dạy học · bản đa nền tảng (Flutter + TypeScript + PostgreSQL).\n'
                'Đồng bộ đa thiết bị theo tài khoản · offline vẫn dùng được.\n'
                'Sổ ghi chép cẩn thận ❦ EST. 2026',
                style: TextStyle(color: Ink2.muted, fontSize: 13, height: 1.6)),
          ]),
        ),
      ]),
    );
  }
}
