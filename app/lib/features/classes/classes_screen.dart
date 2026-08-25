import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../widgets/vintage.dart';
import '../shell.dart';
import 'class_form.dart';

class ClassesScreen extends StatelessWidget {
  const ClassesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final st = AppState.instance;
        return Scaffold(
          appBar: teduBar(context, 'Ca học'),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: Ink2.oxblood,
            foregroundColor: Ink2.cream,
            icon: const Icon(Icons.add),
            label: const Text('Thêm ca học'),
            onPressed: () => openClassForm(context, null),
          ),
          body: RefreshIndicator(
            onRefresh: st.refreshAll,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
              children: [
                for (final c in st.classes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () => openClassForm(context, c),
                      child: PaperCard(
                        child: Row(children: [
                          Container(width: 4, height: 52, color: hexColor(c.color)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(c.name,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                              const SizedBox(height: 3),
                              Text(
                                '${c.days.map((d) => dayNamesVi[d] ?? '?').join(', ')} · ${c.startTime}–${c.endTime}'
                                '${c.subject.isNotEmpty ? ' · ${c.subject}' : ''}',
                                style: const TextStyle(fontSize: 12.5, color: Ink2.muted),
                              ),
                            ]),
                          ),
                          StampBadge('${c.studentIds.length} HS', color: Ink2.navy),
                        ]),
                      ),
                    ),
                  ),
                if (st.classes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Chưa có ca học nào — bấm "Thêm ca học" để tạo.',
                        textAlign: TextAlign.center, style: TextStyle(color: Ink2.muted)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
