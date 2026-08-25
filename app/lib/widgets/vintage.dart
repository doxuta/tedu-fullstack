/// Bộ component "vintage" — chuyển thể trung thực từ bản web:
/// giấy nhám (grain), khung viền kép + hoa văn góc, con dấu bưu điện xoay,
/// nút letterpress, tem trạng thái, dòng kẻ chấm.
library;

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';

/* ═══════════════ GIẤY NHÁM ═══════════════ */

class GrainPainter extends CustomPainter {
  final double opacity;
  final int seed;
  const GrainPainter({this.opacity = .05, this.seed = 7});

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(seed);
    final dark = Paint()..color = Ink2.ink.withValues(alpha: opacity);
    final light = Paint()..color = Colors.white.withValues(alpha: opacity * .8);
    final n = (size.width * size.height / 340).clamp(80, 2600).toInt();
    for (var i = 0; i < n; i++) {
      final p = Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height);
      canvas.drawCircle(p, rnd.nextDouble() * .9 + .3, rnd.nextBool() ? dark : light);
    }
  }

  @override
  bool shouldRepaint(covariant GrainPainter old) =>
      old.opacity != opacity || old.seed != seed;
}

/// Phủ nhám lên bất kỳ widget nào (không chặn chuột).
class Grain extends StatelessWidget {
  final double opacity;
  const Grain({super.key, this.opacity = .05});
  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(painter: GrainPainter(opacity: opacity), size: Size.infinite),
        ),
      );
}

/* ═══════════════ HOA VĂN GÓC ═══════════════ */

class _CornerPainter extends CustomPainter {
  final Color color;
  const _CornerPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color..style = PaintingStyle.stroke..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final s = size.width;
    final path = Path()
      ..moveTo(1.5, s)..lineTo(1.5, s * .34)
      ..quadraticBezierTo(1.5, 1.5, s * .34, 1.5)..lineTo(s, 1.5);
    canvas.drawPath(path, p);
    final p2 = Paint()
      ..color = color.withValues(alpha: .55)..style = PaintingStyle.stroke..strokeWidth = .9;
    final path2 = Path()
      ..moveTo(s * .26, s)..lineTo(s * .26, s * .48)
      ..quadraticBezierTo(s * .26, s * .26, s * .48, s * .26)..lineTo(s, s * .26);
    canvas.drawPath(path2, p2);
    canvas.drawCircle(Offset(s * .27, s * .27), 1.9, Paint()..color = color);
  }
  @override
  bool shouldRepaint(covariant _CornerPainter old) => old.color != color;
}

Widget _corner(double size, Color color, int quarterTurns) => RotatedBox(
      quarterTurns: quarterTurns,
      child: CustomPaint(size: Size.square(size), painter: _CornerPainter(color)),
    );

/* ═══════════════ THẺ GIẤY VIỀN KÉP ═══════════════ */

class PaperCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool ornate;      // thêm hoa văn 4 góc (thẻ trang trọng)
  final bool grain;
  const PaperCard({super.key, required this.child,
      this.padding = const EdgeInsets.all(16), this.ornate = false, this.grain = true});

  @override
  Widget build(BuildContext context) {
    final inner = Container(
      margin: const EdgeInsets.all(3.5),
      decoration: BoxDecoration(
        border: Border.all(color: Ink2.ink.withValues(alpha: .28), width: .9),
      ),
      padding: padding,
      child: child,
    );
    return Container(
      decoration: BoxDecoration(
        color: Ink2.card,
        border: Border.all(color: Ink2.ink.withValues(alpha: .6), width: 1.1),
        boxShadow: const [
          BoxShadow(color: Color(0x1F2B2318), offset: Offset(2.5, 2.5)),
          BoxShadow(color: Color(0x0A2B2318), offset: Offset(6, 6), blurRadius: 8),
        ],
      ),
      child: Stack(children: [
        if (grain) const Positioned.fill(child: Grain(opacity: .035)),
        inner,
        if (ornate) ...[
          Positioned(top: 7, left: 7, child: _corner(15, Ink2.gold, 0)),
          Positioned(top: 7, right: 7, child: _corner(15, Ink2.gold, 1)),
          Positioned(bottom: 7, right: 7, child: _corner(15, Ink2.gold, 2)),
          Positioned(bottom: 7, left: 7, child: _corner(15, Ink2.gold, 3)),
        ],
      ]),
    );
  }
}

/* ═══════════════ CON DẤU BƯU ĐIỆN XOAY ═══════════════ */

class Postmark extends StatefulWidget {
  final double size;
  final String ringText;
  final Color color;
  const Postmark({super.key, this.size = 92,
      this.ringText = 'TEDU · HỌC PHÍ · ĐIỂM DANH · GIÁO ÁN ·', this.color = Ink2.gold});
  @override
  State<Postmark> createState() => _PostmarkState();
}

class _PostmarkState extends State<Postmark> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 40))..repeat();
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _c,
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: _PostmarkPainter(widget.ringText, widget.color),
      ),
    );
  }
}

class _PostmarkPainter extends CustomPainter {
  final String text;
  final Color color;
  const _PostmarkPainter(this.text, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final ring = Paint()
      ..color = color.withValues(alpha: .85)..style = PaintingStyle.stroke..strokeWidth = 1.2;
    // vòng dashed ngoài
    const dashes = 44;
    for (var i = 0; i < dashes; i++) {
      final a1 = i * 2 * pi / dashes, a2 = a1 + pi / dashes * .9;
      canvas.drawArc(Rect.fromCircle(center: c, radius: r - 1.5), a1, a2 - a1, false, ring);
    }
    canvas.drawCircle(c, r * .58, ring..strokeWidth = 1);
    // asterisk giữa
    final tp = TextPainter(
      text: TextSpan(text: '✳',
          style: TextStyle(fontSize: r * .5, color: color.withValues(alpha: .9))),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    // chữ chạy quanh vòng
    final chars = text.split('');
    final radius = r * .78;
    final style = TextStyle(fontSize: r * .17, letterSpacing: 0,
        fontWeight: FontWeight.w700, color: color.withValues(alpha: .9));
    final step = 2 * pi / chars.length;
    for (var i = 0; i < chars.length; i++) {
      final ang = -pi / 2 + i * step;
      canvas.save();
      canvas.translate(c.dx + radius * cos(ang), c.dy + radius * sin(ang));
      canvas.rotate(ang + pi / 2);
      final ctp = TextPainter(
        text: TextSpan(text: chars[i], style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      ctp.paint(canvas, Offset(-ctp.width / 2, -ctp.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _PostmarkPainter old) =>
      old.text != text || old.color != color;
}

/* ═══════════════ NÚT LETTERPRESS ═══════════════ */

class LetterpressButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool ghost;
  const LetterpressButton(this.text, {super.key, this.onPressed, this.icon, this.ghost = false});

  @override
  Widget build(BuildContext context) {
    final fg = ghost ? Ink2.ink : Ink2.cream;
    final bg = ghost ? Colors.transparent : Ink2.oxblood;
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: ghost ? Ink2.ink.withValues(alpha: .5) : Ink2.espresso, width: 1.2),
      ),
      child: InkWell(
        onTap: onPressed,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
                color: ghost ? Colors.transparent : Ink2.cream.withValues(alpha: .35), width: 1),
            boxShadow: ghost ? null : const [
              BoxShadow(color: Color(0x33000000), offset: Offset(0, -1.5), blurRadius: 0, spreadRadius: -1),
            ],
          ),
          margin: const EdgeInsets.all(2),
          padding: EdgeInsets.symmetric(horizontal: icon != null ? 16 : 20, vertical: 12),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 15, color: fg), const SizedBox(width: 7)],
            Text(text.toUpperCase(),
                style: TextStyle(color: fg, fontSize: 12,
                    fontWeight: FontWeight.w800, letterSpacing: 1.8)),
          ]),
        ),
      ),
    );
  }
}

/* ═══════════════ CHIA ĐOẠN FLEURON ═══════════════ */

class Fleuron extends StatelessWidget {
  const Fleuron({super.key});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: Container(height: .8, color: Ink2.gold.withValues(alpha: .5))),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10),
        child: Text('❦', style: TextStyle(color: Ink2.gold, fontSize: 13)),
      ),
      Expanded(child: Container(height: .8, color: Ink2.gold.withValues(alpha: .5))),
    ]);
  }
}

/* ═══════════════ CÁC MẢNH NHỎ ═══════════════ */

class StampBadge extends StatelessWidget {
  final String text;
  final Color color;
  const StampBadge(this.text, {super.key, this.color = Ink2.green});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.2),
        color: color.withValues(alpha: .06),
      ),
      child: Text(text.toUpperCase(),
          style: TextStyle(color: color, fontSize: 10,
              fontWeight: FontWeight.w800, letterSpacing: 1.1)),
    );
  }
}

class DottedRow extends StatelessWidget {
  final String label;
  final Widget value;
  const DottedRow(this.label, this.value, {super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(label, style: const TextStyle(color: Ink2.muted, fontSize: 13)),
        Expanded(child: CustomPaint(
          painter: const _DotsPainter(),
          child: const SizedBox(height: 12),
        )),
        DefaultTextStyle(
          style: const TextStyle(color: Ink2.ink, fontSize: 13.5, fontWeight: FontWeight.w700),
          child: value,
        ),
      ]),
    );
  }
}

class _DotsPainter extends CustomPainter {
  const _DotsPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Ink2.faint;
    for (double x = 5; x < size.width - 3; x += 5.5) {
      canvas.drawCircle(Offset(x, size.height - 3), .9, p);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(children: [
        Container(width: 16, height: 2, color: Ink2.oxblood,
            margin: const EdgeInsets.only(right: 8)),
        Text(text.toUpperCase(),
            style: const TextStyle(fontSize: 10.5, letterSpacing: 2.2,
                fontWeight: FontWeight.w800, color: Ink2.muted)),
      ]),
    );
  }
}

class InitialAvatar extends StatelessWidget {
  final String name;
  const InitialAvatar(this.name, {super.key});
  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final ini = parts.length > 1
        ? '${parts[parts.length - 2][0]}${parts.last[0]}'
        : (name.isEmpty ? '?' : name[0]);
    return Container(
      width: 34, height: 34, alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Ink2.panel, shape: BoxShape.circle,
        border: Border.all(color: Ink2.ink.withValues(alpha: .35)),
      ),
      child: Text(ini.toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Ink2.ink)),
    );
  }
}

/// Chữ viết tay (Dancing Script) — dùng cho câu accent.
class Handwritten extends StatelessWidget {
  final String text;
  final double size;
  final Color color;
  const Handwritten(this.text, {super.key, this.size = 18, this.color = Ink2.gold});
  @override
  Widget build(BuildContext context) => Text(text,
      style: GoogleFonts.dancingScript(fontSize: size, fontWeight: FontWeight.w600, color: color));
}

Color hexColor(String hex, {Color fallback = Ink2.green}) {
  final h = hex.replaceAll('#', '');
  if (h.length != 6) return fallback;
  final v = int.tryParse(h, radix: 16);
  return v == null ? fallback : Color(0xFF000000 | v);
}

void showToast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
}
