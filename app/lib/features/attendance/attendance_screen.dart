import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../widgets/vintage.dart';
import '../shell.dart';

class AttendanceScreen extends StatefulWidget {
  final DateTime? initialDate;
  final String? initialClassId;
  const AttendanceScreen({super.key, this.initialDate, this.initialClassId});
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  late DateTime date = widget.initialDate ?? DateTime.now();
  ClassModel? cls;
  final Map<String, String> marks = {};   // studentId -> status
  final Map<String, String> notes = {};
  bool saving = false;
  bool loadedExisting = false;

  String get iso => date.toIso8601String().substring(0, 10);
  int get dow => date.weekday % 7; // DateTime: T2=1…CN=7 → CN=0

  List<ClassModel> get todayClasses => AppState.instance.classes.where((c) {
        if (!c.days.contains(dow)) return false;
        if (c.startDate.isNotEmpty && iso.compareTo(c.startDate) < 0) return false;
        if (c.endDate.isNotEmpty && iso.compareTo(c.endDate) > 0) return false;
        return true;
      }).toList();

  Future<void> _pickClass(ClassModel c) async {
    setState(() { cls = c; marks.clear(); notes.clear(); loadedExisting = false; });
    // nạp bản điểm danh đã có (nếu có)
    try {
      final r = await AppState.instance.api.get('/attendance?from=$iso&to=$iso&classId=${c.id}');
      final items = ((r as Map)['items'] as List);
      if (items.isNotEmpty) {
        final entry = AttendanceEntry.fromJson(items.first as Map<String, dynamic>);
        for (final rec in entry.records) {
          marks[rec.studentId] = rec.status;
          if (rec.note.isNotEmpty) notes[rec.studentId] = rec.note;
        }
        loadedExisting = true;
      }
    } on ApiException { /* offline → điểm danh mới */ }
    // mặc định: tất cả có mặt
    for (final id in c.studentIds) { marks.putIfAbsent(id, () => 'present'); }
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    if (cls == null) return;
    setState(() => saving = true);
    final records = [
      for (final id in cls!.studentIds)
        AttRecord(studentId: id, status: marks[id] ?? 'present', note: notes[id] ?? ''),
    ];
    await AppState.instance.saveAttendance(iso, cls!.id, records, '');
    if (mounted) {
      setState(() => saving = false);
      showToast(context, AppState.instance.online
          ? 'Đã lưu điểm danh ${fmtDate(iso)}'
          : 'Đã ghi tạm (offline) — sẽ tự đẩy khi có mạng');
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialClassId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final matches = AppState.instance.classes.where((c) => c.id == widget.initialClassId);
        if (matches.isNotEmpty) _pickClass(matches.first);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = AppState.instance;
    return Scaffold(
      appBar: teduBar(context, 'Điểm danh'),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.event, size: 17),
            label: Text(fmtDate(iso)),
            onPressed: () async {
              final d = await showDatePicker(
                context: context, initialDate: date,
                firstDate: DateTime(2020), lastDate: DateTime(2035));
              if (d != null) setState(() { date = d; cls = null; marks.clear(); });
            },
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => setState(() { date = DateTime.now(); cls = null; marks.clear(); }),
            child: const Text('Hôm nay'),
          ),
        ]),
        const SizedBox(height: 14),
        const SectionLabel('Chọn ca'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final c in todayClasses)
            ChoiceChip(
              label: Text('${c.startTime} · ${c.name}'),
              selected: cls?.id == c.id,
              selectedColor: Ink2.panel,
              onSelected: (_) => _pickClass(c),
            ),
          if (todayClasses.isEmpty)
            const Text('Ngày này không có ca theo lịch.', style: TextStyle(color: Ink2.muted)),
        ]),
        if (cls != null) ...[
          const SizedBox(height: 18),
          if (loadedExisting)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: StampBadge('Đã điểm danh — đang sửa lại', color: Ink2.navy),
            ),
          PaperCard(
            child: Column(children: [
              Row(children: [
                Expanded(child: Text(cls!.name,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                TextButton(
                  onPressed: () => setState(() {
                    for (final id in cls!.studentIds) { marks[id] = 'present'; }
                  }),
                  child: const Text('Tất cả có mặt', style: TextStyle(color: Ink2.green)),
                ),
              ]),
              const Divider(),
              for (final id in cls!.studentIds)
                _row(st.studentById(id)?.name ?? '?', id),
            ]),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: saving ? null : _save,
            icon: const Icon(Icons.check),
            label: Text(saving ? 'ĐANG LƯU...' : 'LƯU ĐIỂM DANH'),
          ),
        ],
      ]),
    );
  }

  Widget _row(String name, String id) {
    const options = [
      ('present', 'Có mặt', Ink2.green),
      ('late', 'Muộn', Ink2.mustard),
      ('excused', 'Vắng CP', Ink2.navy),
      ('absent', 'Vắng KP', Ink2.oxblood),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, children: [
          for (final (value, label, color) in options)
            ChoiceChip(
              label: Text(label, style: TextStyle(
                  fontSize: 12,
                  color: marks[id] == value ? Ink2.cream : color)),
              selected: marks[id] == value,
              selectedColor: color,
              backgroundColor: Ink2.card,
              side: BorderSide(color: color.withValues(alpha: .5)),
              onSelected: (_) => setState(() => marks[id] = value),
            ),
        ]),
      ]),
    );
  }
}
