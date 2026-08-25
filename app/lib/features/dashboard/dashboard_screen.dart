import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../widgets/vintage.dart';
import '../shell.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<TodayClass> today = [];
  Map<String, dynamic>? month;
  bool loading = true;
  int _seenVer = -1;

  String get _ym {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final st = AppState.instance;
    try {
      final t = await st.api.get('/stats/today');
      final m = await st.api.get('/stats/month/$_ym');
      if (!mounted) return;
      setState(() {
        today = ((t as Map)['items'] as List)
            .map((e) => TodayClass.fromJson(e as Map<String, dynamic>)).toList();
        month = m as Map<String, dynamic>;
        loading = false;
      });
    } on ApiException {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = AppState.instance;
    if (_seenVer != st.dataVersion) {
      _seenVer = st.dataVersion;
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _load(); });
    }
    final totals = (month?['totals'] as Map<String, dynamic>?) ?? {};
    final unpaid = ((month?['rows'] as List?) ?? [])
        .map((e) => MonthStatRow.fromJson(e as Map<String, dynamic>))
        .where((r) => r.remaining > 0)
        .toList()
      ..sort((a, b) => b.remaining.compareTo(a.remaining));

    return Scaffold(
      appBar: teduBar(context, 'Xin chào, ${st.userName ?? 'bạn'}'),
      body: RefreshIndicator(
        onRefresh: () async { await st.refreshAll(); await _load(); },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (loading) const LinearProgressIndicator(minHeight: 2),
            Wrap(spacing: 12, runSpacing: 12, children: [
              _stat('Đang học', st.students.where((s) => s.status == 'active').length.toString(),
                  '/ ${st.students.length} học sinh'),
              _stat('Ca hôm nay', today.length.toString(),
                  '${st.classes.length} ca đang có'),
              _stat('Buổi tính phí', (totals['sessions'] ?? 0).toString(), 'tháng này'),
              _stat('Dự kiến', fmtMoney((totals['fee'] ?? 0) as int), 'tháng này'),
              _stat('Đã thu', fmtMoney((totals['paid'] ?? 0) as int), '', color: Ink2.green),
              _stat('Còn lại', fmtMoney((totals['remaining'] ?? 0) as int), 'cần thu', color: Ink2.oxblood),
            ]),
            const SizedBox(height: 20),
            const SectionLabel('Ca học hôm nay'),
            PaperCard(
              child: today.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('Hôm nay không có ca nào theo lịch. Nghỉ ngơi thôi ☕',
                          style: TextStyle(color: Ink2.muted)))
                  : Column(children: [
                      for (final c in today)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                  border: Border.all(color: hexColor(c.color)),
                                  color: hexColor(c.color).withValues(alpha: .07)),
                              child: Text('${c.startTime}–${c.endTime}',
                                  style: TextStyle(color: hexColor(c.color),
                                      fontWeight: FontWeight.w700, fontSize: 12.5)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text('${c.name} · ${c.studentCount} HS',
                                    style: const TextStyle(fontWeight: FontWeight.w600))),
                            if (c.attendanceTaken)
                              const StampBadge('✓ Đã điểm danh')
                            else
                              const StampBadge('Chưa điểm danh', color: Ink2.mustard),
                          ]),
                        ),
                    ]),
            ),
            const SizedBox(height: 20),
            const SectionLabel('Chưa thu đủ học phí (tháng này)'),
            PaperCard(
              child: unpaid.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('Đã thu đủ của tất cả học sinh ✓',
                          style: TextStyle(color: Ink2.green, fontWeight: FontWeight.w600)))
                  : Column(children: [
                      for (final r in unpaid)
                        DottedRow('${r.name} · ${r.sessions} buổi',
                            Text(fmtMoney(r.remaining),
                                style: const TextStyle(color: Ink2.oxblood, fontWeight: FontWeight.w800))),
                    ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, String sub, {Color color = Ink2.ink}) {
    return SizedBox(
      width: 168,
      child: PaperCard(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(),
              style: const TextStyle(fontSize: 9.5, letterSpacing: 1.6,
                  color: Ink2.muted, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: color)),
          if (sub.isNotEmpty)
            Text(sub, style: const TextStyle(fontSize: 11, color: Ink2.faint)),
        ]),
      ),
    );
  }
}
