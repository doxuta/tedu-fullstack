/// Khung điều hướng: rail đầy đủ (desktop) / 4 tab + menu "Thêm" (mobile).
library;
import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../widgets/vintage.dart';
import 'dashboard/dashboard_screen.dart';
import 'students/students_screen.dart';
import 'classes/classes_screen.dart';
import 'attendance/attendance_screen.dart';
import 'fees/fees_screen.dart';
import 'settings/settings_screen.dart';
import 'scores/scores_screen.dart';
import 'lessons/lessons_screen.dart';
import 'timetable/timetable_screen.dart';
import 'ai/ai_screen.dart';
import 'admin/admin_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});
  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _NavItem {
  final IconData icon;
  final String Function() label;
  final Widget Function() page;
  const _NavItem(this.icon, this.label, this.page);
}

class _ShellScreenState extends State<ShellScreen> {
  int _index = 0;

  List<_NavItem> get _all => [
        _NavItem(Icons.grid_view_rounded, () => L.t('Tổng quan', 'Overview', '대시보드'), () => const DashboardScreen()),
        _NavItem(Icons.bolt_outlined, () => L.t('Trợ lý AI', 'AI', 'AI'), () => const AiScreen()),
        _NavItem(Icons.people_alt_outlined, () => L.t('Học sinh', 'Students', '학생'), () => const StudentsScreen()),
        _NavItem(Icons.menu_book_outlined, () => L.t('Ca học', 'Classes', '수업'), () => const ClassesScreen()),
        _NavItem(Icons.calendar_month_outlined, () => L.t('TKB', 'Timetable', '시간표'), () => const TimetableScreen()),
        _NavItem(Icons.check_circle_outline, () => L.t('Điểm danh', 'Attendance', '출석'), () => const AttendanceScreen()),
        _NavItem(Icons.payments_outlined, () => L.t('Học phí', 'Tuition', '수업료'), () => const FeesScreen()),
        _NavItem(Icons.bar_chart_outlined, () => L.t('Điểm KT', 'Scores', '점수'), () => const ScoresScreen()),
        _NavItem(Icons.auto_stories_outlined, () => L.t('Giáo án', 'Lessons', '일지'), () => const LessonsScreen()),
        _NavItem(Icons.tune, () => L.t('Cài đặt', 'Settings', '설정'), () => const SettingsScreen()),
        if (AppState.instance.userRole == 'admin')
          _NavItem(Icons.shield_outlined, () => L.t('Quản trị', 'Admin', '관리자'), () => const AdminScreen()),
      ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final items = _all;
        if (_index >= items.length) _index = 0;
        final wide = MediaQuery.of(context).size.width >= 760;

        if (wide) {
          return Scaffold(
            body: Row(children: [
              Container(
                color: Ink2.espresso,
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height),
                    child: IntrinsicHeight(
                      child: NavigationRail(
                        backgroundColor: Ink2.espresso,
                        selectedIndex: _index,
                        onDestinationSelected: (i) => setState(() => _index = i),
                        labelType: NavigationRailLabelType.all,
                        selectedIconTheme: const IconThemeData(color: Ink2.gold),
                        unselectedIconTheme: IconThemeData(color: Ink2.cream.withValues(alpha: .6)),
                        selectedLabelTextStyle: const TextStyle(color: Ink2.cream, fontWeight: FontWeight.w700, fontSize: 11.5),
                        unselectedLabelTextStyle: TextStyle(color: Ink2.cream.withValues(alpha: .55), fontSize: 11.5),
                        leading: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Container(
                            width: 38, height: 38, alignment: Alignment.center,
                            decoration: BoxDecoration(border: Border.all(color: Ink2.gold, width: 1.4)),
                            child: const Text('T*', style: TextStyle(color: Ink2.cream, fontWeight: FontWeight.w800, fontSize: 15)),
                          ),
                        ),
                        destinations: [
                          for (final it in items)
                            NavigationRailDestination(icon: Icon(it.icon), label: Text(it.label())),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: Stack(children: [
                items[_index].page(),
                const Positioned.fill(child: Grain(opacity: .022)),
              ])),
            ]),
          );
        }

        // Mobile: 4 tab chính + "Thêm"
        final primary = [items[0], items[5], items[6], items[1]]; // Tổng quan, Điểm danh, Học phí, AI
        final more = items.where((it) => !primary.contains(it)).toList();
        final primaryIndex = primary.indexWhere((it) => items.indexOf(it) == _index);

        return Scaffold(
          body: Stack(children: [
            items[_index].page(),
            const Positioned.fill(child: Grain(opacity: .022)),
          ]),
          bottomNavigationBar: NavigationBar(
            backgroundColor: Ink2.card,
            indicatorColor: Ink2.panel,
            height: 64,
            selectedIndex: primaryIndex >= 0 ? primaryIndex : 4,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            onDestinationSelected: (i) {
              if (i < 4) {
                setState(() => _index = items.indexOf(primary[i]));
              } else {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Ink2.card,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  builder: (c) => SafeArea(
                    child: Wrap(children: [
                      for (final it in more)
                        ListTile(
                          leading: Icon(it.icon, color: Ink2.ink),
                          title: Text(it.label()),
                          onTap: () {
                            Navigator.pop(c);
                            setState(() => _index = items.indexOf(it));
                          },
                        ),
                    ]),
                  ),
                );
              }
            },
            destinations: [
              for (final it in primary)
                NavigationDestination(icon: Icon(it.icon), label: it.label()),
              NavigationDestination(icon: const Icon(Icons.apps), label: L.t('Thêm', 'More', '더보기')),
            ],
          ),
        );
      },
    );
  }
}

/// AppBar dùng chung, kèm đèn online/offline + nút đẩy hàng đợi.
PreferredSizeWidget teduBar(BuildContext context, String title, {List<Widget>? actions}) {
  final st = AppState.instance;
  return AppBar(
    title: Row(mainAxisSize: MainAxisSize.min, children: [
      Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
      const SizedBox(width: 8),
      Tooltip(
        message: st.realtimeOn
            ? L.t('Trực tuyến — thiết bị khác đổi là thấy ngay', 'Live sync on', '실시간 동기화')
            : L.t('Chưa nối realtime', 'Realtime off', '실시간 꺼짐'),
        child: Container(
          width: 8, height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle,
              color: st.realtimeOn ? Ink2.green : Ink2.faint),
        ),
      ),
    ]),
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(6),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(children: [
          Container(height: 1.6, color: Ink2.ink.withValues(alpha: .75)),
          const SizedBox(height: 2.5),
          Container(height: .8, color: Ink2.ink.withValues(alpha: .35)),
        ]),
      ),
    ),
    actions: [
      if (!st.online || st.pendingOps.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ActionChip(
            avatar: Icon(st.online ? Icons.cloud_upload_outlined : Icons.cloud_off,
                size: 16, color: Ink2.oxblood),
            label: Text(st.online
                ? L.t('Đẩy ${st.pendingOps.length} thay đổi', 'Push ${st.pendingOps.length}', '${st.pendingOps.length} 푸시')
                : 'Offline · ${st.pendingOps.length}'),
            onPressed: () async {
              final n = await st.flushPending();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(n > 0
                        ? L.t('Đã đồng bộ $n thay đổi', 'Synced $n changes', '$n개 동기화됨')
                        : L.t('Chưa kết nối được máy chủ', 'Still offline', '연결 실패'))));
              }
            },
          ),
        ),
      ...?actions,
    ],
  );
}
