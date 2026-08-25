import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../widgets/vintage.dart';
import '../shell.dart';
import 'receipt_screen.dart';

class FeesScreen extends StatefulWidget {
  const FeesScreen({super.key});
  @override
  State<FeesScreen> createState() => _FeesScreenState();
}

class _FeesScreenState extends State<FeesScreen> {
  late DateTime month;
  List<MonthStatRow> rows = [];
  Map<String, dynamic> totals = {};
  bool loading = true;
  int _seenVer = -1;

  String get ym => '${month.year}-${month.month.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    month = DateTime(DateTime.now().year, DateTime.now().month);
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final r = await AppState.instance.api.get('/stats/month/$ym');
      if (!mounted) return;
      setState(() {
        rows = ((r as Map)['rows'] as List)
            .map((e) => MonthStatRow.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => b.remaining.compareTo(a.remaining));
        totals = (r['totals'] as Map<String, dynamic>);
        loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) { setState(() => loading = false); showToast(context, e.message); }
    }
  }

  Future<void> _collect(MonthStatRow r) async {
    final amount = TextEditingController(
        text: r.remaining > 0 ? r.remaining.toString() : '');
    var method = 'Chuyển khoản';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          backgroundColor: Ink2.card,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          title: Text('Thu học phí – ${r.name}'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DottedRow('${r.sessions} buổi × ${fmtMoney(r.rate)}', Text(fmtMoney(r.fee))),
            DottedRow('Đã thu', Text(fmtMoney(r.paid))),
            const SizedBox(height: 12),
            TextField(controller: amount, keyboardType: TextInputType.number, autofocus: true,
                decoration: const InputDecoration(labelText: 'Số tiền thu (đ)')),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(spacing: 6, children: [
                for (final m in const ['Chuyển khoản', 'Tiền mặt'])
                  ChoiceChip(
                    label: Text(m),
                    selected: method == m,
                    selectedColor: Ink2.panel,
                    onSelected: (_) => setLocal(() => method = m),
                  ),
              ]),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Huỷ')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('XÁC NHẬN THU')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final amt = int.tryParse(amount.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (amt <= 0) return;
    await AppState.instance.recordPayment(Payment(
      id: genUuid(), studentId: r.studentId, month: ym, amount: amt,
      paidAt: DateTime.now().toIso8601String().substring(0, 10), method: method,
    ));
    if (mounted) {
      showToast(context, 'Đã ghi nhận ${fmtMoney(amt)} — ${r.name}');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final stApp = AppState.instance;
    if (_seenVer != stApp.dataVersion) {
      _seenVer = stApp.dataVersion;
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _load(); });
    }
    final monthLabel = 'Tháng ${month.month}/${month.year}';
    return Scaffold(
      appBar: teduBar(context, 'Học phí'),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Row(children: [
            IconButton(onPressed: () { setState(() => month = DateTime(month.year, month.month - 1)); _load(); },
                icon: const Icon(Icons.chevron_left)),
            Expanded(child: Text(monthLabel, textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge)),
            IconButton(onPressed: () { setState(() => month = DateTime(month.year, month.month + 1)); _load(); },
                icon: const Icon(Icons.chevron_right)),
          ]),
          const SizedBox(height: 8),
          if (loading) const LinearProgressIndicator(minHeight: 2),
          PaperCard(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              DottedRow('Buổi tính phí', Text('${totals['sessions'] ?? 0}')),
              DottedRow('Học phí dự kiến', Text(fmtMoney((totals['fee'] ?? 0) as int))),
              DottedRow('Đã thu', Text(fmtMoney((totals['paid'] ?? 0) as int),
                  style: const TextStyle(color: Ink2.green, fontWeight: FontWeight.w800))),
              DottedRow('Còn lại', Text(fmtMoney((totals['remaining'] ?? 0) as int),
                  style: const TextStyle(color: Ink2.oxblood, fontWeight: FontWeight.w800))),
            ]),
          ),
          const SizedBox(height: 16),
          const SectionLabel('Từng học sinh'),
          if (!loading && !rows.any((x) => x.sessions > 0 || x.paid > 0))
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Tháng này chưa có buổi học nào được điểm danh.\nĐiểm danh xong, học phí sẽ tự cộng vào đây.',
                  textAlign: TextAlign.center, style: TextStyle(color: Ink2.muted, height: 1.6)),
            ),
          for (final r in rows.where((x) => x.sessions > 0 || x.paid > 0))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PaperCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  InitialAvatar(r.name),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('${r.sessions} buổi · đã thu ${fmtMoney(r.paid)}',
                          style: const TextStyle(fontSize: 12, color: Ink2.muted)),
                    ]),
                  ),
                  if (r.remaining <= 0)
                    const StampBadge('✓ Đã thu đủ')
                  else ...[
                    Text(fmtMoney(r.remaining),
                        style: const TextStyle(color: Ink2.oxblood, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 8),
                    OutlinedButton(onPressed: () => _collect(r), child: const Text('Thu')),
                  ],
                  IconButton(
                    tooltip: 'Phiếu học phí',
                    icon: const Icon(Icons.receipt_long_outlined, size: 19),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => ReceiptScreen(row: r, ym: ym))).then((_) => _load()),
                  ),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}
