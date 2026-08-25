import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import '../../data/models.dart';
import '../../core/theme.dart';
import '../../widgets/vintage.dart';

const _palette = ['#2F5D50', '#33506B', '#9A3B2E', '#C8922A', '#3E7C7B', '#6B8E23'];

Future<void> openClassForm(BuildContext context, ClassModel? existing) async {
  final st = AppState.instance;
  final isNew = existing == null;
  final c = existing ??
      ClassModel(
        id: genUuid(), name: '',
        days: [], color: _palette[st.classes.length % _palette.length],
        startDate: DateTime.now().toIso8601String().substring(0, 10),
      );

  final name = TextEditingController(text: c.name);
  final subject = TextEditingController(text: c.subject);
  final start = TextEditingController(text: c.startTime);
  final end = TextEditingController(text: c.endTime);
  final days = {...c.days};
  final selected = {...c.studentIds};

  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setLocal) => AlertDialog(
        backgroundColor: Ink2.card,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Text(isNew ? 'Thêm ca học' : 'Sửa ca học'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Tên ca *')),
              const SizedBox(height: 10),
              TextField(controller: subject, decoration: const InputDecoration(labelText: 'Môn')),
              const SizedBox(height: 12),
              const Text('HỌC VÀO THỨ', style: TextStyle(fontSize: 10, letterSpacing: 1.5, color: Ink2.muted, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, children: [
                for (final d in const [1, 2, 3, 4, 5, 6, 0])
                  FilterChip(
                    label: Text(dayNamesVi[d]!),
                    selected: days.contains(d),
                    selectedColor: Ink2.panel,
                    onSelected: (v) => setLocal(() => v ? days.add(d) : days.remove(d)),
                  ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: start,
                    decoration: const InputDecoration(labelText: 'Bắt đầu (HH:MM)'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: end,
                    decoration: const InputDecoration(labelText: 'Kết thúc (HH:MM)'))),
              ]),
              const SizedBox(height: 12),
              Text('HỌC SINH TRONG CA (${selected.length})',
                  style: const TextStyle(fontSize: 10, letterSpacing: 1.5, color: Ink2.muted, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: Column(children: [
                    for (final s in st.students.where((x) => x.status != 'stopped'))
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(s.name, style: const TextStyle(fontSize: 13.5)),
                        value: selected.contains(s.id),
                        onChanged: (v) => setLocal(() =>
                            v == true ? selected.add(s.id) : selected.remove(s.id)),
                      ),
                  ]),
                ),
              ),
            ]),
          ),
        ),
        actions: [
          if (!isNew)
            TextButton(
              onPressed: () async {
                await st.deleteClass(c.id);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Xoá', style: TextStyle(color: Ink2.oxblood)),
            ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Huỷ')),
          ElevatedButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) { showToast(context, 'Chưa nhập tên ca'); return; }
              if (days.isEmpty) { showToast(context, 'Chọn ít nhất 1 thứ trong tuần'); return; }
              final hhmm = RegExp(r'^\d{2}:\d{2}$');
              if (!hhmm.hasMatch(start.text) || !hhmm.hasMatch(end.text)) {
                showToast(context, 'Giờ phải dạng HH:MM (VD 18:00)'); return;
              }
              c.name = name.text.trim();
              c.subject = subject.text.trim();
              c.days = days.toList()..sort();
              c.startTime = start.text;
              c.endTime = end.text;
              c.studentIds = selected.toList();
              await st.saveClass(c, isNew: isNew);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('LƯU'),
          ),
        ],
      ),
    ),
  );
}
