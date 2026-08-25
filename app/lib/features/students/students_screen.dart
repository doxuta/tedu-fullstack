import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../widgets/vintage.dart';
import '../shell.dart';
import 'student_form.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});
  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final st = AppState.instance;
        final list = st.students.where((s) {
          if (_q.isEmpty) return true;
          final q = _q.toLowerCase();
          return s.name.toLowerCase().contains(q) ||
              s.grade.toLowerCase().contains(q) ||
              s.parentPhone.contains(q);
        }).toList();

        return Scaffold(
          appBar: teduBar(context, 'Học sinh'),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: Ink2.oxblood,
            foregroundColor: Ink2.cream,
            icon: const Icon(Icons.add),
            label: const Text('Thêm học sinh'),
            onPressed: () => openStudentForm(context, null),
          ),
          body: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search, size: 20),
                    hintText: 'Tìm tên, lớp, SĐT...'),
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: st.refreshAll,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final s = list[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      leading: InitialAvatar(s.name),
                      title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                          [if (s.grade.isNotEmpty) s.grade, if (s.subject.isNotEmpty) s.subject].join(' · '),
                          style: const TextStyle(fontSize: 12.5, color: Ink2.muted)),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${fmtMoney(s.rate)} / buổi',
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 3),
                          StampBadge(
                            switch (s.status) { 'paused' => 'Tạm nghỉ', 'stopped' => 'Đã nghỉ', _ => 'Đang học' },
                            color: switch (s.status) { 'paused' => Ink2.mustard, 'stopped' => Ink2.faint, _ => Ink2.green },
                          ),
                        ],
                      ),
                      onTap: () => openStudentForm(context, s),
                    );
                  },
                ),
              ),
            ),
          ]),
        );
      },
    );
  }
}
