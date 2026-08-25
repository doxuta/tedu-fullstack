import 'package:flutter_test/flutter_test.dart';
import 'package:tedu/core/app_state.dart';
import 'package:tedu/core/theme.dart';

void main() {
  test('genUuid ra uuid v4 hợp lệ và không trùng', () {
    final a = genUuid(), b = genUuid();
    final rx = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
    expect(rx.hasMatch(a), true);
    expect(a == b, false);
  });

  test('fmtMoney có dấu chấm ngăn cách', () {
    expect(fmtMoney(1620000), '1.620.000\u00A0₫'); // NBSP — ký hiệu tiền không bao giờ rớt dòng
    expect(fmtMoney(0), '0\u00A0₫');
  });

  test('fmtDate đảo về dd/MM/yyyy', () {
    expect(fmtDate('2026-07-15'), '15/07/2026');
  });
}
