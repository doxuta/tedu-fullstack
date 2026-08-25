/// Trợ lý AI — bộ hiểu lệnh tiếng Việt offline + Gemini (khoá tuỳ chọn),
/// mọi lệnh ghi sổ đều qua thẻ xác nhận.
library;

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/app_state.dart';
import '../../core/api_client.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../shell.dart';

/* ---------- tiện ích tiếng Việt ---------- */
const _viMap = 'àáạảãâầấậẩẫăằắặẳẵ:aèéẹẻẽêềếệểễ:eìíịỉĩ:iòóọỏõôồốộổỗơờớợởỡ:oùúụủũưừứựửữ:uỳýỵỷỹ:yđ:d';
String deAccent(String s) {
  var out = s.toLowerCase();
  for (final group in _viMap.split(RegExp(r'(?<=:.)'))) {
    if (group.length < 3) continue;
    final target = group[group.length - 1];
    final chars = group.substring(0, group.length - 2);
    for (final ch in chars.split('')) { out = out.replaceAll(ch, target); }
  }
  return out;
}

int moneyIn(String raw) {
  final s = deAccent(raw).replaceAll('.', '');
  var m = RegExp(r'(\d+)\s*(?:trieu|tr)(?![a-z])\s*(\d)?').firstMatch(s);
  if (m != null) return int.parse(m.group(1)!) * 1000000 + (m.group(2) != null ? int.parse(m.group(2)!) * 100000 : 0);
  m = RegExp(r'(\d+(?:,\d+)?)\s*(?:k|nghin|ngan)(?![a-z])').firstMatch(s);
  if (m != null) return (double.parse(m.group(1)!.replaceAll(',', '.')) * 1000).round();
  m = RegExp(r'(?:^|[^0-9a-z])(\d{4,9})(?![0-9])').firstMatch(s);
  if (m != null) return int.parse(m.group(1)!);
  return 0;
}

/* ---------- model tin nhắn ---------- */
class _Msg {
  final bool me;
  final String text;
  final List<_Action> actions;
  _Msg(this.me, this.text, [this.actions = const []]);
}

class _Action {
  final String label;             // mô tả hiển thị
  final Future<String> Function() run; // thực thi → thông điệp kết quả
  String? result;
  _Action(this.label, this.run);
}

class AiScreen extends StatefulWidget {
  const AiScreen({super.key});
  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> {
  final input = TextEditingController();
  final scroll = ScrollController();
  final List<_Msg> log = [];
  bool busy = false;

  AppState get st => AppState.instance;

  @override
  void initState() {
    super.initState();
    log.add(_Msg(false, L.t(
        'Chào bạn! Tôi là thư ký của tiệm. Thử: "thêm học sinh Lan lớp 8A giá 160k" · "thu Minh Anh 500k" · "ai chưa đóng tiền?" · "hôm nay dạy gì?". Mọi lệnh ghi sổ đều có nút xác nhận trước khi làm.',
        'Hello! Try: "add student Lan grade 8A 160k" (Vietnamese commands) or ask about your data. Every write needs your confirmation.',
        '안녕하세요! 명령을 입력해 보세요. 모든 기록은 확인 후 실행됩니다.')));
  }

  void _push(_Msg m) {
    setState(() => log.add(m));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) {
        scroll.animateTo(scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    final text = input.text.trim();
    if (text.isEmpty || busy) return;
    input.clear();
    _push(_Msg(true, text));
    final local = _parse(text);
    if (local != null) { _push(local); return; }
    final key = (st.userSettings['geminiKey'] ?? '') as String;
    if (key.isEmpty) {
      _push(_Msg(false, L.t(
          'Tôi chưa hiểu câu này ở chế độ cơ bản. Dán khoá Gemini miễn phí ở Cài đặt để tôi hiểu mọi kiểu nói (aistudio.google.com/app/apikey).',
          'I did not get that in basic mode. Paste a free Gemini key in Settings for natural chat.',
          '기본 모드에서 이해하지 못했습니다. 설정에서 Gemini 키를 추가하세요.')));
      return;
    }
    setState(() => busy = true);
    try {
      final reply = await _askGemini(key, text);
      _push(reply);
    } catch (e) {
      _push(_Msg(false, '⚠ $e'));
    } finally {
      setState(() => busy = false);
    }
  }

  /* ---------- parser offline ---------- */
  _Msg? _parse(String text) {
    final nt = deAccent(text).replaceAll(RegExp(r'\s+'), ' ').trim();

    Student? findStudent(String q) {
      final nq = deAccent(q).trim();
      final hits = st.students.where((s) => deAccent(s.name).contains(nq)).toList();
      return hits.length == 1 ? hits.first : null;
    }

    // hỏi đáp nhanh
    if (RegExp(r'(hom nay|bua nay).*(day|hoc|ca|lich)|^hom nay day gi').hasMatch(nt)) {
      final today = DateTime.now();
      final dow = today.weekday % 7;
      final items = st.classes.where((c) => c.days.contains(dow)).toList();
      if (items.isEmpty) return _Msg(false, L.t('Hôm nay không có ca nào theo lịch ☕', 'No classes today ☕', '오늘 수업 없음 ☕'));
      return _Msg(false, items.map((c) => '• ${c.startTime}–${c.endTime}  ${c.name} (${c.studentIds.length} HS)').join('\n'));
    }
    if (RegExp(r'bao nhieu hoc sinh|si so|may hoc sinh').hasMatch(nt)) {
      final act = st.students.where((s) => s.status == 'active').length;
      return _Msg(false, L.t('Đang có ${st.students.length} học sinh ($act đang học) · ${st.classes.length} ca.',
          '${st.students.length} students ($act active) · ${st.classes.length} classes.',
          '학생 ${st.students.length}명 · 수업 ${st.classes.length}개'));
    }
    if (RegExp(r'(ai|em nao).*(chua (dong|nop|thu)|con (no|thieu))|chua dong tien|tong thu|thu duoc bao nhieu').hasMatch(nt)) {
      return _Msg(false, L.t(
          'Số liệu học phí chi tiết nằm ở mục Học phí (tab 💳) — mở là thấy ai còn thiếu bao nhiêu, bấm Thu để ghi nhận.',
          'Detailed tuition numbers live in the Tuition tab — open it to see who still owes.',
          '수업료 탭에서 미납 내역을 확인하세요.'));
    }
    // xem hồ sơ
    var m = RegExp(r'^(?:xem|thong tin|ho so)\s+(.+)$').firstMatch(nt);
    if (m != null) {
      final s = findStudent(m.group(1)!);
      if (s != null) {
        return _Msg(false,
            '${s.name} · ${s.grade}\n${s.subject} · ${fmtMoney(s.rate)}/buổi · ${s.status == 'active' ? 'đang học' : s.status == 'paused' ? 'tạm nghỉ' : 'đã nghỉ'}'
            '${s.parentName.isNotEmpty ? '\nPH: ${s.parentName} ${s.parentPhone}' : ''}');
      }
    }
    // thêm học sinh
    m = RegExp(r'^(?:them|tao)\s+(?:hoc sinh|hs|em)\s+(.+)$').firstMatch(nt);
    if (m != null) {
      final tokens = text.trim().split(RegExp(r'\s+'));
      final ntok = tokens.map(deAccent).toList();
      const kw = ['lop', 'truong', 'mon', 'gia', 'don', 'sdt', 'phu', 'ph', 'me', 'bo'];
      var i = ntok.indexWhere((t) => t == 'sinh' || t == 'hs' || t == 'em') + 1;
      var end = i;
      while (end < ntok.length && !kw.contains(ntok[end])) { end++; }
      final name = tokens.sublist(i, end).join(' ');
      if (name.isEmpty) return _Msg(false, 'Bạn cho tôi xin tên học sinh nhé.');
      String grab(List<String> kws) {
        final idx = ntok.indexWhere((t) => kws.contains(t));
        if (idx < 0) return '';
        var j = idx + 1;
        if (ntok[idx] == 'don' && j < ntok.length && ntok[j] == 'gia') j++;
        if (ntok[idx] == 'phu' && j < ntok.length && ntok[j] == 'huynh') j++;
        var k = j;
        while (k < ntok.length && !kw.contains(ntok[k]) && k - j < 4) { k++; }
        return tokens.sublist(j, k).join(' ');
      }
      final s = Student(
        id: genUuid(), name: name,
        grade: grab(['lop', 'truong']), subject: grab(['mon']),
        rate: moneyIn(nt) > 0 ? moneyIn(nt) : 150000,
        parentName: grab(['phu', 'ph', 'me', 'bo']),
        startDate: DateTime.now().toIso8601String().substring(0, 10),
      );
      final tel = RegExp(r'\b(0\d{9,10})\b').firstMatch(nt);
      if (tel != null) s.parentPhone = tel.group(1)!;
      return _Msg(false, L.t('Bạn xem lại rồi bấm Thực hiện nhé:', 'Review and confirm:', '확인 후 실행:'), [
        _Action('➕ ${s.name} · ${s.grade.isNotEmpty ? '${s.grade} · ' : ''}${fmtMoney(s.rate)}/buổi',
            () async { await st.saveStudent(s, isNew: true); return 'Đã thêm ${s.name}'; }),
      ]);
    }
    // xoá học sinh
    m = RegExp(r'^xoa\s+(?:hoc sinh|hs|em)\s+(.+)$').firstMatch(nt);
    if (m != null) {
      final s = findStudent(m.group(1)!);
      if (s == null) return _Msg(false, 'Không tìm thấy (hoặc trùng nhiều em) — gõ đầy đủ tên nhé.');
      return _Msg(false, L.t('Xác nhận trước khi xoá:', 'Confirm delete:', '삭제 확인:'), [
        _Action('🗑 Xoá ${s.name} (cùng dữ liệu liên quan)',
            () async { await st.deleteStudent(s.id); return 'Đã xoá ${s.name}'; }),
      ]);
    }
    // đổi giá
    m = RegExp(r'^(?:doi|sua|dat)\s+(?:don\s*)?gia\s+(?:cua\s+)?(.+?)\s+(?:thanh|la)?\s*([\d.,]+\s*(?:k|nghin|tr|trieu)?)$').firstMatch(nt);
    if (m != null) {
      final s = findStudent(m.group(1)!);
      final r = moneyIn(m.group(2)!);
      if (s == null || r == 0) return _Msg(false, 'Chưa bắt được tên/số tiền — thử "đổi giá Lan thành 200k".');
      return _Msg(false, L.t('Xác nhận:', 'Confirm:', '확인:'), [
        _Action('✎ ${s.name}: ${fmtMoney(s.rate)} → ${fmtMoney(r)}/buổi', () async {
          s.rate = r;
          await st.saveStudent(s, isNew: false);
          return 'Đã đổi đơn giá ${s.name}';
        }),
      ]);
    }
    // thu tiền
    m = RegExp(r'^(?:thu|nop)\s+(?:tien|hoc phi)?\s*(?:cua\s+)?(.+?)\s+([\d.,]+\s*(?:k|nghin|tr|trieu|d|dong)?)$').firstMatch(nt);
    if (m != null) {
      final s = findStudent(m.group(1)!);
      final amt = moneyIn(m.group(2)!);
      if (s == null || amt == 0) return _Msg(false, 'Chưa bắt được tên/số tiền — thử "thu Minh Anh 500k".');
      final now = DateTime.now();
      final ym = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      return _Msg(false, L.t('Xác nhận:', 'Confirm:', '확인:'), [
        _Action('💰 Thu ${fmtMoney(amt)} của ${s.name} (tháng ${now.month}/${now.year})', () async {
          await st.recordPayment(Payment(
              id: genUuid(), studentId: s.id, month: ym, amount: amt,
              paidAt: DateTime.now().toIso8601String().substring(0, 10)));
          return 'Đã ghi nhận ${fmtMoney(amt)} — ${s.name}';
        }),
      ]);
    }
    // cho điểm
    m = RegExp(r'^cho\s+(.+?)\s+(\d{1,2}(?:[.,]\d)?)\s*diem(?:\s+(?:bai\s*)?(.*))?$').firstMatch(nt);
    if (m != null) {
      final s = findStudent(m.group(1)!);
      final v = double.tryParse(m.group(2)!.replaceAll(',', '.'));
      if (s == null || v == null || v > 10) return _Msg(false, 'Thử "cho Gia Bảo 8 điểm bài thi thử".');
      final title = (m.group(3) ?? '').trim();
      return _Msg(false, L.t('Xác nhận:', 'Confirm:', '확인:'), [
        _Action('📊 ${s.name}: $v điểm${title.isNotEmpty ? ' — $title' : ''}', () async {
          await st.upsert('/scores', {
            'id': genUuid(), 'studentId': s.id, 'score': v,
            'title': title.isEmpty ? 'Kiểm tra' : title,
            'date': DateTime.now().toIso8601String().substring(0, 10),
          });
          return 'Đã lưu điểm $v — ${s.name}';
        }),
      ]);
    }
    return null;
  }

  /* ---------- Gemini ---------- */
  Future<_Msg> _askGemini(String key, String text) async {
    final ctx = jsonEncode({
      'today': DateTime.now().toIso8601String().substring(0, 10),
      'students': st.students.map((s) => {'id': s.id, 'name': s.name, 'grade': s.grade, 'rate': s.rate, 'status': s.status}).toList(),
      'classes': st.classes.map((c) => {'id': c.id, 'name': c.name, 'days': c.days, 'start': c.startTime}).toList(),
    });
    final langName = switch (L.lang) { 'en' => 'English', 'ko' => 'Korean', _ => 'Vietnamese' };
    final sys = 'You are the assistant inside TEdu, a tutoring ledger app. '
        'Reply STRICT JSON only: {"reply": string in $langName, "actions": []}. '
        'Actions allowed: {"type":"add_student","name":..,"grade":..,"rate":int} · '
        '{"type":"record_payment","studentId":..,"amount":int} · {"type":"add_score","studentId":..,"score":num,"title":..} · '
        '{"type":"delete_student","studentId":..}. Use exact ids from CONTEXT; if unsure ask back with actions:[]. '
        'CONTEXT=$ctx';
    for (final model in const ['gemini-2.5-flash', 'gemini-2.0-flash', 'gemini-1.5-flash']) {
      final res = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$key'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'system_instruction': {'parts': [{'text': sys}]},
          'contents': [{'role': 'user', 'parts': [{'text': text}]}],
          'generationConfig': {'temperature': 0.2, 'responseMimeType': 'application/json'},
        }),
      );
      if (res.statusCode == 404) continue;
      if (res.statusCode != 200) {
        throw 'Gemini lỗi ${res.statusCode}${res.statusCode == 400 ? ' — kiểm tra khoá API' : ''}';
      }
      final j = jsonDecode(utf8.decode(res.bodyBytes));
      final cands = (j['candidates'] as List?) ?? [];
      if (cands.isEmpty) throw 'Gemini trả về rỗng';
      final parts = ((cands.first['content']?['parts']) as List?) ?? [];
      final txt = parts.map((p) => '${p['text'] ?? ''}').join();
      final obj = jsonDecode(txt.toString().replaceAll(RegExp(r'^```(json)?|```$'), '').trim());
      final actions = <_Action>[];
      for (final a in ((obj['actions'] ?? []) as List)) {
        final act = _fromGeminiAction(a as Map<String, dynamic>);
        if (act != null) actions.add(act);
      }
      return _Msg(false, '${obj['reply'] ?? ''}', actions);
    }
    throw 'Không gọi được mô hình Gemini nào';
  }

  _Action? _fromGeminiAction(Map<String, dynamic> a) {
    switch (a['type']) {
      case 'add_student':
        final s = Student(
            id: genUuid(), name: '${a['name'] ?? ''}', grade: '${a['grade'] ?? ''}',
            rate: (a['rate'] as num?)?.toInt() ?? 150000,
            startDate: DateTime.now().toIso8601String().substring(0, 10));
        if (s.name.isEmpty) return null;
        return _Action('➕ ${s.name} · ${fmtMoney(s.rate)}/buổi',
            () async { await st.saveStudent(s, isNew: true); return 'Đã thêm ${s.name}'; });
      case 'record_payment':
        final sid = '${a['studentId'] ?? ''}';
        final stu = st.studentById(sid);
        final amt = (a['amount'] as num?)?.toInt() ?? 0;
        if (stu == null || amt <= 0) return null;
        final now = DateTime.now();
        return _Action('💰 Thu ${fmtMoney(amt)} của ${stu.name}', () async {
          await st.recordPayment(Payment(
              id: genUuid(), studentId: sid,
              month: '${now.year}-${now.month.toString().padLeft(2, '0')}',
              amount: amt, paidAt: now.toIso8601String().substring(0, 10)));
          return 'Đã ghi nhận ${fmtMoney(amt)}';
        });
      case 'add_score':
        final sid = '${a['studentId'] ?? ''}';
        final stu = st.studentById(sid);
        final v = (a['score'] as num?)?.toDouble();
        if (stu == null || v == null) return null;
        return _Action('📊 ${stu.name}: $v điểm', () async {
          await st.upsert('/scores', {
            'id': genUuid(), 'studentId': sid, 'score': v,
            'title': '${a['title'] ?? 'Kiểm tra'}',
            'date': DateTime.now().toIso8601String().substring(0, 10),
          });
          return 'Đã lưu điểm';
        });
      case 'delete_student':
        final stu = st.studentById('${a['studentId'] ?? ''}');
        if (stu == null) return null;
        return _Action('🗑 Xoá ${stu.name}',
            () async { await st.deleteStudent(stu.id); return 'Đã xoá ${stu.name}'; });
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final hasKey = ((st.userSettings['geminiKey'] ?? '') as String).isNotEmpty;
    return Scaffold(
      appBar: teduBar(context, L.t('Trợ lý AI', 'AI Assistant', 'AI 비서')),
      body: Column(children: [
        Expanded(
          child: ListView.builder(
            controller: scroll,
            padding: const EdgeInsets.all(14),
            itemCount: log.length,
            itemBuilder: (context, i) => _bubble(log[i]),
          ),
        ),
        if (busy) const LinearProgressIndicator(minHeight: 2),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: input,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(hintText: L.t(
                        'Hỏi hoặc ra lệnh... (thu Minh Anh 500k)',
                        'Ask or command...', '질문 또는 명령...')),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _send, child: const Icon(Icons.arrow_forward, size: 18)),
              ]),
              const SizedBox(height: 5),
              Text(
                hasKey
                    ? L.t('Gemini ✓ — hỏi gì cũng được, luôn xác nhận trước khi ghi',
                        'Gemini ✓ — ask anything, writes always confirmed', 'Gemini ✓')
                    : L.t('Chế độ cơ bản — dán khoá Gemini ở Cài đặt để chat tự nhiên',
                        'Basic mode — add a Gemini key in Settings', '기본 모드'),
                style: const TextStyle(fontSize: 10.5, color: Ink2.muted),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _bubble(_Msg m) {
    return Align(
      alignment: m.me ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 520),
        decoration: BoxDecoration(
          color: m.me ? Ink2.espresso : Ink2.card,
          border: Border.all(color: m.me ? Ink2.espresso : Ink2.line),
          boxShadow: const [BoxShadow(color: Color(0x122B2318), offset: Offset(2, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(m.text, style: TextStyle(color: m.me ? Ink2.cream : Ink2.ink, fontSize: 13.5, height: 1.5)),
          for (final a in m.actions) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Ink2.panel, border: Border.all(color: Ink2.ink.withValues(alpha: .4))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(a.label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                if (a.result == null)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                      onPressed: () async {
                        try {
                          final r = await a.run();
                          setState(() => a.result = r);
                        } on ApiException catch (e) {
                          setState(() => a.result = '⚠ ${e.message}');
                        }
                      },
                      child: Text(L.t('THỰC HIỆN', 'CONFIRM', '실행'), style: const TextStyle(fontSize: 11)),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                      onPressed: () => setState(() => a.result = L.t('Đã huỷ', 'Cancelled', '취소됨')),
                      child: Text(L.t('HUỶ', 'CANCEL', '취소'), style: const TextStyle(fontSize: 11)),
                    ),
                  ])
                else
                  Text(a.result!, style: TextStyle(fontSize: 12,
                      color: a.result!.startsWith('⚠') || a.result!.contains('huỷ') || a.result!.contains('Cancel')
                          ? Ink2.muted : Ink2.green,
                      fontWeight: FontWeight.w700)),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}
