/// Thời khoá biểu tuần — 7 cột ngày thật, ô ca bấm mở điểm danh.
library;
import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import '../../core/api_client.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../widgets/vintage.dart';
import '../shell.dart';
import '../attendance/attendance_screen.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});
  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  late DateTime monday;
  Set<String> taken = {}; // "date|classId" đã điểm danh

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    monday = now.subtract(Duration(days: (now.weekday - 1)));
    _loadTaken();
  }

  String _iso(DateTime d) => d.toIso8601String().substring(0, 10);

  Future<void> _loadTaken() async {
    try {
      final from = _iso(monday), to = _iso(monday.add(const Duration(days: 6)));
      final r = await AppState.instance.api.get('/attendance?from=$from&to=$to');
      final items = ((r as Map)['items'] as List).cast<Map<String, dynamic>>();
      if (mounted) {
        setState(() => taken = items.map((e) => '${e['date']}|${e['classId']}').toSet());
      }
    } on ApiException { /* offline */ }
  }

  List<ClassModel> _classesOn(DateTime day) {
    final iso = _iso(day);
    final dow = day.weekday % 7;
    return AppState.instance.classes.where((c) {
      if (!c.days.contains(dow)) return false;
      if (c.startDate.isNotEmpty && iso.compareTo(c.startDate) < 0) return false;
      if (c.endDate.isNotEmpty && iso.compareTo(c.endDate) > 0) return false;
      return true;
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  @override
  Widget build(BuildContext context) {
    final today = _iso(DateTime.now());
    final days = List.generate(7, (i) => monday.add(Duration(days: i)));
    final range =
        '${fmtDate(_iso(monday))} – ${fmtDate(_iso(monday.add(const Duration(days: 6))))}';

    return Scaffold(
      appBar: teduBar(context, L.t('Thời khoá biểu', 'Timetable', '시간표')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.chevron_left),
                onPressed: () { setState(() => monday = monday.subtract(const Duration(days: 7))); _loadTaken(); }),
            Expanded(child: Text(range, textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700))),
            OutlinedButton(
              onPressed: () {
                final now = DateTime.now();
                setState(() => monday = now.subtract(Duration(days: now.weekday - 1)));
                _loadTaken();
              },
              child: Text(L.t('Hôm nay', 'Today', '오늘')),
            ),
            IconButton(icon: const Icon(Icons.chevron_right),
                onPressed: () { setState(() => monday = monday.add(const Duration(days: 7))); _loadTaken(); }),
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
            child: LayoutBuilder(builder: (context, cons) {
              final colW = (cons.maxWidth / 7).clamp(96.0, 220.0);
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (final d in days)
                    SizedBox(
                      width: colW,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Column(children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: _iso(d) == today ? Ink2.gold.withValues(alpha: .18) : Ink2.panel,
                              border: Border.all(color: Ink2.line),
                            ),
                            child: Column(children: [
                              Text(dayNamesVi[d.weekday % 7] ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                              Text('${d.day}/${d.month}',
                                  style: const TextStyle(fontSize: 10.5, color: Ink2.muted)),
                            ]),
                          ),
                          const SizedBox(height: 6),
                          for (final c in _classesOn(d))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: InkWell(
                                onTap: () => Navigator.push(context, MaterialPageRoute(
                                    builder: (_) => AttendanceScreen(
                                        initialDate: d, initialClassId: c.id))).then((_) => _loadTaken()),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: Ink2.card,
                                    border: Border(
                                      left: BorderSide(color: hexColor(c.color), width: 3),
                                      top: const BorderSide(color: Ink2.line),
                                      right: const BorderSide(color: Ink2.line),
                                      bottom: const BorderSide(color: Ink2.line),
                                    ),
                                  ),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(
                                      '${taken.contains('${_iso(d)}|${c.id}') ? '✓ ' : ''}${c.startTime}',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                                          color: taken.contains('${_iso(d)}|${c.id}') ? Ink2.green : hexColor(c.color)),
                                    ),
                                    Text(c.name,
                                        maxLines: 2, overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                                  ]),
                                ),
                              ),
                            ),
                          if (_classesOn(d).isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 10),
                              child: Text('—', style: TextStyle(color: Ink2.faint)),
                            ),
                        ]),
                      ),
                    ),
                ]),
              );
            }),
          ),
        ),
      ]),
    );
  }
}
