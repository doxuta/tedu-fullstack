/// Phiếu học phí vintage — hiển thị + VietQR + xuất PDF / in (mọi nền tảng).
library;
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import '../../core/app_state.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../widgets/vintage.dart';

class ReceiptScreen extends StatefulWidget {
  final MonthStatRow row;
  final String ym; // YYYY-MM
  const ReceiptScreen({super.key, required this.row, required this.ym});

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  final note = TextEditingController();

  String get _qrUrl {
    final s = AppState.instance.userSettings;
    final bank = (s['bankId'] ?? '') as String;
    final acc = (s['bankAcc'] ?? '') as String;
    final holder = Uri.encodeComponent((s['bankHolder'] ?? '') as String);
    if (bank.isEmpty || acc.isEmpty) return '';
    final remaining = widget.row.remaining > 0 ? widget.row.remaining : 0;
    final info = Uri.encodeComponent('HP ${widget.ym} ${widget.row.name}');
    return 'https://img.vietqr.io/image/$bank-$acc-qr_only.png'
        '?amount=$remaining&addInfo=$info&accountName=$holder';
  }

  String get _monthLabel => '${widget.ym.substring(5)}/${widget.ym.substring(0, 4)}';

  Future<void> _exportPdf() async {
    final r = widget.row;
    pw.MemoryImage? qrImg;
    if (_qrUrl.isNotEmpty && r.remaining > 0) {
      try {
        final res = await http.get(Uri.parse(_qrUrl));
        if (res.statusCode == 200) qrImg = pw.MemoryImage(res.bodyBytes);
      } catch (_) {}
    }
    final s = AppState.instance.userSettings;
    final fontBase = await PdfGoogleFonts.beVietnamProRegular();
    final fontBold = await PdfGoogleFonts.beVietnamProBold();
    final doc = pw.Document(
        theme: pw.ThemeData.withFont(base: fontBase, bold: fontBold));
    pw.Widget dotted(String label, String value) => pw.Row(children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 11, color: PdfColor.fromInt(0xFF7A6F5C))),
          pw.Expanded(child: pw.Container(
              margin: const pw.EdgeInsets.symmetric(horizontal: 4),
              decoration: const pw.BoxDecoration(border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColor.fromInt(0xFFA39A85), width: .7, style: pw.BorderStyle.dotted))))),
          pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        ]);

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a5,
      build: (ctx) => pw.Container(
        padding: const pw.EdgeInsets.all(18),
        decoration: pw.BoxDecoration(
          color: const PdfColor.fromInt(0xFFF7F2E3),
          border: pw.Border.all(color: const PdfColor.fromInt(0xFF2B2318), width: 1.2),
        ),
        child: pw.Container(
          margin: const pw.EdgeInsets.all(4),
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: const PdfColor.fromInt(0x882B2318), width: .7)),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
            pw.Center(child: pw.Text('TEDU', style: const pw.TextStyle(fontSize: 9, letterSpacing: 4, color: PdfColor.fromInt(0xFFB08D3F)))),
            pw.SizedBox(height: 4),
            pw.Center(child: pw.Text('PHIẾU HỌC PHÍ', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold))),
            pw.Center(child: pw.Text('Tháng $_monthLabel', style: const pw.TextStyle(fontSize: 11, color: PdfColor.fromInt(0xFF7A6F5C)))),
            pw.SizedBox(height: 14),
            dotted('Học sinh', r.name),
            pw.SizedBox(height: 5),
            dotted('Đơn giá mỗi buổi', fmtMoney(r.rate)),
            pw.SizedBox(height: 5),
            dotted('Số buổi đã học', '${r.sessions} buổi'),
            pw.SizedBox(height: 5),
            dotted('Đã thu', fmtMoney(r.paid)),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 8),
              decoration: const pw.BoxDecoration(border: pw.Border(
                top: pw.BorderSide(color: PdfColor.fromInt(0xFF2B2318), width: 1.4),
                bottom: pw.BorderSide(color: PdfColor.fromInt(0xFF2B2318), width: 1.4),
              )),
              child: pw.Column(children: [
                pw.Text('TỔNG HỌC PHÍ', style: const pw.TextStyle(fontSize: 9, letterSpacing: 3, color: PdfColor.fromInt(0xFF7A6F5C))),
                pw.SizedBox(height: 3),
                pw.Text(fmtMoney(r.fee), style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold)),
                if (r.remaining > 0)
                  pw.Text('Còn lại: ${fmtMoney(r.remaining)}',
                      style: pw.TextStyle(fontSize: 12, color: const PdfColor.fromInt(0xFF93392C), fontWeight: pw.FontWeight.bold))
                else
                  pw.Text('— ĐÃ THU ĐỦ —', style: pw.TextStyle(fontSize: 12, color: const PdfColor.fromInt(0xFF2F5D50), fontWeight: pw.FontWeight.bold)),
              ]),
            ),
            if (note.text.trim().isNotEmpty) ...[
              pw.SizedBox(height: 10),
              pw.Text('Nhận xét: ${note.text.trim()}', style: pw.TextStyle(fontSize: 11, fontStyle: pw.FontStyle.italic)),
            ],
            if (qrImg != null) ...[
              pw.SizedBox(height: 12),
              pw.Center(child: pw.Container(
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(border: pw.Border.all(color: const PdfColor.fromInt(0xFF2B2318), width: .8)),
                child: pw.Image(qrImg, width: 110, height: 110),
              )),
              pw.SizedBox(height: 4),
              pw.Center(child: pw.Text(
                  'Quét để thanh toán · ${s['bankId'] ?? ''} ${s['bankAcc'] ?? ''} · ${s['bankHolder'] ?? ''}',
                  style: const pw.TextStyle(fontSize: 8.5, color: PdfColor.fromInt(0xFF7A6F5C)))),
            ],
            pw.Spacer(),
            pw.Center(child: pw.Text('Cảm ơn quý phụ huynh ❦ TEdu',
                style: const pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF7A6F5C)))),
          ]),
        ),
      ),
    ));
    await Printing.layoutPdf(
        onLayout: (_) => doc.save(),
        name: 'phieu-hoc-phi-${widget.row.name}-${widget.ym}.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.row;
    return Scaffold(
      appBar: AppBar(title: Text(L.t('Phiếu học phí', 'Tuition receipt', '수업료 영수증'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(children: [
              PaperCard(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  const Text('TEDU', style: TextStyle(fontSize: 9, letterSpacing: 4, color: Ink2.gold, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('PHIẾU HỌC PHÍ', style: Theme.of(context).textTheme.headlineSmall),
                  Text('Tháng $_monthLabel', style: const TextStyle(color: Ink2.muted, fontSize: 12)),
                  const SizedBox(height: 16),
                  DottedRow(L.t('Học sinh', 'Student', '학생'), Text(r.name)),
                  DottedRow(L.t('Đơn giá mỗi buổi', 'Rate / session', '회당 단가'), Text(fmtMoney(r.rate))),
                  DottedRow(L.t('Số buổi đã học', 'Sessions', '수업 횟수'), Text('${r.sessions}')),
                  DottedRow(L.t('Đã thu', 'Paid', '납부액'), Text(fmtMoney(r.paid))),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: const BoxDecoration(border: Border(
                      top: BorderSide(color: Ink2.ink, width: 1.4),
                      bottom: BorderSide(color: Ink2.ink, width: 1.4),
                    )),
                    child: Column(children: [
                      const Text('TỔNG HỌC PHÍ',
                          style: TextStyle(fontSize: 9.5, letterSpacing: 3, color: Ink2.muted, fontWeight: FontWeight.w800)),
                      Text(fmtMoney(r.fee),
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 34)),
                      if (r.remaining > 0)
                        Text('${L.t('Còn lại', 'Remaining', '남은 금액')}: ${fmtMoney(r.remaining)}',
                            style: const TextStyle(color: Ink2.oxblood, fontWeight: FontWeight.w800))
                      else
                        Transform.rotate(
                          angle: -.08,
                          child: Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(border: Border.all(color: Ink2.oxblood, width: 2)),
                            child: const Text('ĐÃ THU ĐỦ',
                                style: TextStyle(color: Ink2.oxblood, fontWeight: FontWeight.w900, letterSpacing: 2)),
                          ),
                        ),
                    ]),
                  ),
                  if (_qrUrl.isNotEmpty && r.remaining > 0) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(border: Border.all(color: Ink2.ink.withValues(alpha: .5))),
                      child: Image.network(_qrUrl, width: 150, height: 150,
                          errorBuilder: (_, __, ___) => const Padding(
                              padding: EdgeInsets.all(12),
                              child: Text('Không tải được VietQR (cần internet)',
                                  style: TextStyle(fontSize: 11, color: Ink2.muted)))),
                    ),
                    const SizedBox(height: 4),
                    Text(L.t('Quét để thanh toán số tiền còn lại', 'Scan to pay the remaining amount', '남은 금액 결제 QR'),
                        style: const TextStyle(fontSize: 11, color: Ink2.muted)),
                  ],
                  if (_qrUrl.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                          L.t('Điền mã ngân hàng + số TK ở Cài đặt để phiếu tự sinh VietQR.',
                              'Add bank code + account in Settings to auto-generate VietQR.',
                              '설정에서 은행 정보를 입력하면 VietQR이 생성됩니다.'),
                          style: const TextStyle(fontSize: 11.5, color: Ink2.muted), textAlign: TextAlign.center),
                    ),
                  const SizedBox(height: 10),
                  const Text('Cảm ơn quý phụ huynh ❦ TEdu',
                      style: TextStyle(fontSize: 11, color: Ink2.muted)),
                ]),
              ),
              const SizedBox(height: 14),
              TextField(controller: note,
                  decoration: InputDecoration(
                      labelText: L.t('Nhận xét in trên phiếu (tuỳ chọn)', 'Comment on the receipt (optional)', '영수증 코멘트 (선택)')),
                  onChanged: (_) => setState(() {})),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: _exportPdf,
                icon: const Icon(Icons.print),
                label: Text(L.t('IN / LƯU PDF', 'PRINT / SAVE PDF', '인쇄 / PDF 저장')),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
