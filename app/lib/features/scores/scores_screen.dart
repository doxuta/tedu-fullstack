import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import '../../core/api_client.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../widgets/vintage.dart';
import '../shell.dart';

class ScoresScreen extends StatefulWidget {
  const ScoresScreen({super.key});
  @override
  State<ScoresScreen> createState() => _ScoresScreenState();
}

class _ScoresScreenState extends State<ScoresScreen> {
  List<Map<String, dynamic>> scores = [];
  String? filterStudent;
  bool loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final items = await AppState.instance.fetchList('/scores');
      items.sort((a, b) => (b['date'] as String? ?? '').compareTo(a['date'] as String? ?? ''));
      if (mounted) setState(() { scores = items; loading = false; });
    } on ApiException catch (e) {
      if (mounted) { setState(() => loading = false); showToast(context, e.message); }
    }
  }

  List<Map<String, dynamic>> get filtered => filterStudent == null
      ? scores : scores.where((s) => s['studentId'] == filterStudent).toList();

  Future<void> _openForm([Map<String, dynamic>? existing]) async {
    final st = AppState.instance;
    if (st.students.isEmpty) { showToast(context, 'Thêm học sinh trước đã nhé'); return; }
    var studentId = (existing?['studentId'] as String?) ?? filterStudent ?? st.students.first.id;
    final title = TextEditingController(text: (existing?['title'] as String?) ?? '');
    final score = TextEditingController(text: existing == null ? '' : '${existing['score']}');
    final note = TextEditingController(text: (existing?['note'] as String?) ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          backgroundColor: Ink2.card,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          title: Text(existing == null
              ? L.t('Thêm điểm', 'Add score', '점수 추가')
              : L.t('Sửa điểm', 'Edit score', '점수 수정')),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final s in st.students.where((x) => x.status != 'stopped'))
                    ChoiceChip(
                      label: Text(s.name, style: const TextStyle(fontSize: 12)),
                      selected: studentId == s.id,
                      selectedColor: Ink2.panel,
                      onSelected: (_) => setLocal(() => studentId = s.id),
                    ),
                ]),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(flex: 2, child: TextField(controller: title,
                    decoration: InputDecoration(labelText: L.t('Tên bài (VD: KT 15 phút)', 'Test name', '시험 이름')))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: score,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: L.t('Điểm (0–10)', 'Score (0–10)', '점수 (0–10)')))),
              ]),
              const SizedBox(height: 10),
              TextField(controller: note,
                  decoration: InputDecoration(labelText: L.t('Nhận xét', 'Comment', '코멘트'))),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false),
                child: Text(L.t('Huỷ', 'Cancel', '취소'))),
            ElevatedButton(onPressed: () => Navigator.pop(context, true),
                child: Text(L.t('LƯU', 'SAVE', '저장'))),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final v = double.tryParse(score.text.replaceAll(',', '.'));
    if (v == null || v < 0 || v > 10) {
      if (mounted) showToast(context, L.t('Điểm phải từ 0 đến 10', 'Score must be 0–10', '점수는 0–10'));
      return;
    }
    await AppState.instance.upsert('/scores', {
      'id': (existing?['id'] as String?) ?? genUuid(),
      'studentId': studentId,
      'score': v,
      'title': title.text.trim().isEmpty ? 'Kiểm tra' : title.text.trim(),
      'date': (existing?['date'] as String?) ?? DateTime.now().toIso8601String().substring(0, 10),
      'note': note.text.trim(),
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final st = AppState.instance;
    final chartData = filterStudent == null ? <Map<String, dynamic>>[] :
        (filtered.reversed.toList());
    return Scaffold(
      appBar: teduBar(context, L.t('Điểm kiểm tra', 'Test scores', '시험 점수')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Ink2.oxblood, foregroundColor: Ink2.cream,
        icon: const Icon(Icons.add),
        label: Text(L.t('Thêm điểm', 'Add score', '점수 추가')),
        onPressed: () => _openForm(),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 90), children: [
          Wrap(spacing: 6, runSpacing: 6, children: [
            ChoiceChip(
              label: Text(L.t('Tất cả', 'All', '전체')),
              selected: filterStudent == null,
              selectedColor: Ink2.panel,
              onSelected: (_) => setState(() => filterStudent = null),
            ),
            for (final s in st.students)
              ChoiceChip(
                label: Text(s.name, style: const TextStyle(fontSize: 12)),
                selected: filterStudent == s.id,
                selectedColor: Ink2.panel,
                onSelected: (_) => setState(() => filterStudent = s.id),
              ),
          ]),
          if (loading) const Padding(padding: EdgeInsets.only(top: 10), child: LinearProgressIndicator(minHeight: 2)),
          if (filterStudent != null && chartData.length >= 2) ...[
            const SizedBox(height: 14),
            SectionLabel(L.t('Biểu đồ tiến bộ', 'Progress chart', '성장 그래프')),
            PaperCard(
              child: SizedBox(height: 180,
                  child: CustomPaint(size: Size.infinite, painter: _ChartPainter(chartData))),
            ),
          ],
          const SizedBox(height: 14),
          for (final sc in filtered)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: PaperCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  Container(
                    width: 42, height: 42, alignment: Alignment.center,
                    decoration: BoxDecoration(
                        border: Border.all(color: _scoreColor((sc['score'] as num).toDouble()), width: 1.4)),
                    child: Text('${sc['score']}',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15,
                            color: _scoreColor((sc['score'] as num).toDouble()))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${st.studentById(sc['studentId'] as String)?.name ?? '?'} · ${sc['title']}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('${fmtDate(sc['date'] as String? ?? '')}'
                        '${(sc['note'] as String? ?? '').isNotEmpty ? ' · ${sc['note']}' : ''}',
                        style: const TextStyle(fontSize: 12, color: Ink2.muted)),
                  ])),
                  IconButton(icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: () => _openForm(sc)),
                  IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Ink2.oxblood),
                      onPressed: () async {
                        await st.remove('/scores/${sc['id']}');
                        _load();
                      }),
                ]),
              ),
            ),
        ]),
      ),
    );
  }

  Color _scoreColor(double v) =>
      v >= 8 ? Ink2.green : v >= 6.5 ? Ink2.navy : v >= 5 ? Ink2.mustard : Ink2.oxblood;
}

class _ChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  _ChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    const padL = 28.0, padB = 22.0, padT = 12.0, padR = 12.0;
    final w = size.width - padL - padR, h = size.height - padT - padB;
    final values = data.map((e) => (e['score'] as num).toDouble()).toList();
    var lo = values.reduce((a, b) => a < b ? a : b) - .5;
    var hi = values.reduce((a, b) => a > b ? a : b) + .5;
    if (hi - lo < 2) { final m = (hi + lo) / 2; lo = m - 1; hi = m + 1; }
    lo = lo.clamp(0, 10); hi = hi.clamp(0, 10);

    final axis = Paint()..color = Ink2.faint..strokeWidth = 1;
    final grid = Paint()..color = Ink2.line..strokeWidth = .7;
    final line = Paint()..color = Ink2.oxblood..strokeWidth = 2..style = PaintingStyle.stroke;
    final dot = Paint()..color = Ink2.oxblood;

    canvas.drawLine(Offset(padL, padT), Offset(padL, padT + h), axis);
    canvas.drawLine(Offset(padL, padT + h), Offset(padL + w, padT + h), axis);

    void label(String s, Offset o) {
      final tp = TextPainter(
          text: TextSpan(text: s, style: const TextStyle(fontSize: 9, color: Ink2.muted)),
          textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, o);
    }

    for (var i = 0; i <= 4; i++) {
      final v = lo + (hi - lo) * i / 4;
      final y = padT + h - h * i / 4;
      canvas.drawLine(Offset(padL, y), Offset(padL + w, y), grid);
      label(v.toStringAsFixed(1), Offset(2, y - 5));
    }

    final pts = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = padL + (values.length == 1 ? w / 2 : w * i / (values.length - 1));
      final y = padT + h - h * ((values[i] - lo) / (hi - lo));
      pts.add(Offset(x, y));
    }
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) { path.lineTo(p.dx, p.dy); }
    canvas.drawPath(path, line);
    for (var i = 0; i < pts.length; i++) {
      canvas.drawCircle(pts[i], 3.4, dot);
      label('${values[i]}', Offset(pts[i].dx - 8, pts[i].dy - 16));
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) => old.data != data;
}
