import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import '../../data/models.dart';
import '../../core/theme.dart';
import '../../widgets/vintage.dart';

Future<void> openStudentForm(BuildContext context, Student? existing) async {
  final st = AppState.instance;
  final isNew = existing == null;
  final s = existing ??
      Student(id: genUuid(), name: '', rate: 150000, startDate: DateTime.now().toIso8601String().substring(0, 10));

  final name = TextEditingController(text: s.name);
  final grade = TextEditingController(text: s.grade);
  final subject = TextEditingController(text: s.subject);
  final rate = TextEditingController(text: s.rate == 0 ? '' : s.rate.toString());
  final parentName = TextEditingController(text: s.parentName);
  final parentPhone = TextEditingController(text: s.parentPhone);
  final note = TextEditingController(text: s.note);
  var status = s.status;

  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setLocal) => AlertDialog(
        backgroundColor: Ink2.card,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Text(isNew ? 'Thêm học sinh' : 'Sửa học sinh'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Họ tên *')),
              const SizedBox(height: 10),
              TextField(controller: grade, decoration: const InputDecoration(labelText: 'Lớp / Trường')),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextField(controller: subject, decoration: const InputDecoration(labelText: 'Môn học'))),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(controller: rate, keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Đơn giá / buổi (đ)')),
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextField(controller: parentName, decoration: const InputDecoration(labelText: 'Phụ huynh'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: parentPhone, keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'SĐT phụ huynh'))),
              ]),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(spacing: 6, children: [
                  for (final (v, label) in const [('active', 'Đang học'), ('paused', 'Tạm nghỉ'), ('stopped', 'Đã nghỉ')])
                    ChoiceChip(
                      label: Text(label),
                      selected: status == v,
                      selectedColor: Ink2.panel,
                      onSelected: (_) => setLocal(() => status = v),
                    ),
                ]),
              ),
              const SizedBox(height: 10),
              TextField(controller: note, maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Ghi chú')),
            ]),
          ),
        ),
        actions: [
          if (!isNew)
            TextButton(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c2) => AlertDialog(
                    title: const Text('Xoá học sinh?'),
                    content: Text('Xoá "${s.name}" cùng điểm danh, học phí liên quan (xoá mềm, đồng bộ mọi máy).'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c2, false), child: const Text('Huỷ')),
                      TextButton(onPressed: () => Navigator.pop(c2, true),
                          child: const Text('Xoá', style: TextStyle(color: Ink2.oxblood))),
                    ],
                  ),
                );
                if (ok == true && context.mounted) {
                  await st.deleteStudent(s.id);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('Xoá', style: TextStyle(color: Ink2.oxblood)),
            ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Huỷ')),
          ElevatedButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) { showToast(context, 'Chưa nhập họ tên'); return; }
              s.name = name.text.trim();
              s.grade = grade.text.trim();
              s.subject = subject.text.trim();
              s.rate = int.tryParse(rate.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
              s.parentName = parentName.text.trim();
              s.parentPhone = parentPhone.text.trim();
              s.note = note.text.trim();
              s.status = status;
              await st.saveStudent(s, isNew: isNew);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('LƯU'),
          ),
        ],
      ),
    ),
  );
}
