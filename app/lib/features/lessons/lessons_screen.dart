import 'dart:convert';
import 'dart:io' show File, Directory;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import '../../core/app_state.dart';
import '../../core/api_client.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../widgets/vintage.dart';
import '../shell.dart';

class LessonsScreen extends StatefulWidget {
  const LessonsScreen({super.key});
  @override
  State<LessonsScreen> createState() => _LessonsScreenState();
}

class _LessonsScreenState extends State<LessonsScreen> {
  List<Map<String, dynamic>> lessons = [];
  List<Map<String, dynamic>> files = [];
  bool loading = true;
  String q = '';

  List<Map<String, dynamic>> filesOf(String lessonId) =>
      files.where((f) => f['lessonId'] == lessonId).toList();

  Future<void> _attach(String lessonId) async {
    final picked = await FilePicker.platform.pickFiles(withData: true);
    final f = picked?.files.first;
    if (f == null || f.bytes == null) return;
    if (f.bytes!.length > 15 * 1024 * 1024) {
      if (mounted) showToast(context, 'File quá lớn (tối đa 15MB)');
      return;
    }
    try {
      await AppState.instance.api.post('/files', {
        'lessonId': lessonId,
        'name': f.name,
        'mime': 'application/octet-stream',
        'dataBase64': base64Encode(f.bytes!),
      });
      if (mounted) showToast(context, 'Đã đính kèm ${f.name}');
      _load();
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    }
  }

  Future<void> _openFile(Map<String, dynamic> meta) async {
    try {
      final r = await AppState.instance.api.get('/files/${meta['id']}');
      final item = (r as Map)['item'] as Map<String, dynamic>;
      final bytes = base64Decode(item['dataBase64'] as String);
      final dir = await Directory.systemTemp.createTemp('tedu');
      final path = '${dir.path}/${item['name']}';
      await File(path).writeAsBytes(bytes);
      await OpenFilex.open(path);
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    }
  }

  Future<void> _deleteFile(String id) async {
    try {
      await AppState.instance.api.delete('/files/$id');
      _load();
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    }
  }

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final items = await AppState.instance.fetchList('/lessons');
      items.sort((a, b) => (b['date'] as String? ?? '').compareTo(a['date'] as String? ?? ''));
      final fs = await AppState.instance.fetchList('/files');
      if (mounted) setState(() { lessons = items; files = fs; loading = false; });
    } on ApiException catch (e) {
      if (mounted) { setState(() => loading = false); showToast(context, e.message); }
    }
  }

  Future<void> _openForm([Map<String, dynamic>? existing]) async {
    final st = AppState.instance;
    final title = TextEditingController(text: (existing?['title'] as String?) ?? '');
    final content = TextEditingController(text: (existing?['content'] as String?) ?? '');
    final homework = TextEditingController(text: (existing?['homework'] as String?) ?? '');
    String? classId = existing?['classId'] as String?;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          backgroundColor: Ink2.card,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          title: Text(existing == null
              ? L.t('Thêm giáo án', 'Add lesson', '일지 추가')
              : L.t('Sửa giáo án', 'Edit lesson', '일지 수정')),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: title,
                    decoration: InputDecoration(labelText: L.t('Tiêu đề *', 'Title *', '제목 *'))),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(spacing: 6, runSpacing: 6, children: [
                    ChoiceChip(
                      label: Text(L.t('Không gắn ca', 'No class', '수업 미지정'),
                          style: const TextStyle(fontSize: 12)),
                      selected: classId == null,
                      selectedColor: Ink2.panel,
                      onSelected: (_) => setLocal(() => classId = null),
                    ),
                    for (final c in st.classes)
                      ChoiceChip(
                        label: Text(c.name, style: const TextStyle(fontSize: 12)),
                        selected: classId == c.id,
                        selectedColor: Ink2.panel,
                        onSelected: (_) => setLocal(() => classId = c.id),
                      ),
                  ]),
                ),
                const SizedBox(height: 10),
                TextField(controller: content, maxLines: 5,
                    decoration: InputDecoration(
                        labelText: L.t('Nội dung buổi dạy', 'Lesson content', '수업 내용'),
                        alignLabelWithHint: true)),
                const SizedBox(height: 10),
                TextField(controller: homework, maxLines: 2,
                    decoration: InputDecoration(labelText: L.t('Bài tập về nhà', 'Homework', '숙제'))),
              ]),
            ),
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
    if (title.text.trim().isEmpty) {
      if (mounted) showToast(context, L.t('Chưa nhập tiêu đề', 'Title is missing', '제목을 입력하세요'));
      return;
    }
    await AppState.instance.upsert('/lessons', {
      'id': (existing?['id'] as String?) ?? genUuid(),
      'title': title.text.trim(),
      'classId': classId,
      'content': content.text,
      'homework': homework.text,
      'date': (existing?['date'] as String?) ?? DateTime.now().toIso8601String().substring(0, 10),
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final st = AppState.instance;
    final list = lessons.where((l) {
      if (q.isEmpty) return true;
      final s = q.toLowerCase();
      return ('${l['title']}'.toLowerCase().contains(s)) ||
          ('${l['content']}'.toLowerCase().contains(s));
    }).toList();
    return Scaffold(
      appBar: teduBar(context, L.t('Giáo án', 'Lessons', '수업 일지')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Ink2.oxblood, foregroundColor: Ink2.cream,
        icon: const Icon(Icons.add),
        label: Text(L.t('Thêm giáo án', 'Add lesson', '일지 추가')),
        onPressed: () => _openForm(),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search, size: 20),
                hintText: L.t('Tìm tiêu đề, nội dung...', 'Search title, content...', '제목·내용 검색...')),
            onChanged: (v) => setState(() => q = v),
          ),
        ),
        if (loading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 90), children: [
              for (final l in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: PaperCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text('${l['title']}',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                        IconButton(icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () => _openForm(l)),
                        IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Ink2.oxblood),
                            onPressed: () async { await st.remove('/lessons/${l['id']}'); _load(); }),
                      ]),
                      Row(children: [
                        StampBadge(fmtDate(l['date'] as String? ?? ''), color: Ink2.navy),
                        const SizedBox(width: 6),
                        if (l['classId'] != null)
                          StampBadge(
                            st.classes.where((c) => c.id == l['classId']).map((c) => c.name).join(),
                            color: Ink2.green,
                          ),
                      ]),
                      if (('${l['content']}').trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('${l['content']}',
                            style: const TextStyle(fontSize: 13, height: 1.5, color: Ink2.ink)),
                      ],
                      if (('${l['homework']}').trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text('✎ ${L.t('BTVN', 'HW', '숙제')}: ${l['homework']}',
                            style: const TextStyle(fontSize: 12.5, color: Ink2.muted, fontStyle: FontStyle.italic)),
                      ],
                      const SizedBox(height: 8),
                      Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        for (final f in filesOf(l['id'] as String))
                          InputChip(
                            avatar: const Icon(Icons.description_outlined, size: 15),
                            label: Text('${f['name']}', style: const TextStyle(fontSize: 11.5)),
                            onPressed: () => _openFile(f),
                            onDeleted: () => _deleteFile(f['id'] as String),
                            deleteIconColor: Ink2.oxblood,
                            backgroundColor: Ink2.panel,
                            side: BorderSide(color: Ink2.ink.withValues(alpha: .3)),
                          ),
                        ActionChip(
                          avatar: const Icon(Icons.attach_file, size: 15, color: Ink2.navy),
                          label: Text(L.t('Đính kèm', 'Attach', '첨부'),
                              style: const TextStyle(fontSize: 11.5, color: Ink2.navy)),
                          onPressed: () => _attach(l['id'] as String),
                          backgroundColor: Colors.transparent,
                          side: const BorderSide(color: Ink2.navy),
                        ),
                      ]),
                    ]),
                  ),
                ),
              if (list.isEmpty && !loading)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(L.t('Chưa có giáo án nào.', 'No lessons yet.', '일지가 없습니다.'),
                      textAlign: TextAlign.center, style: const TextStyle(color: Ink2.muted)),
                ),
            ]),
          ),
        ),
      ]),
    );
  }
}
