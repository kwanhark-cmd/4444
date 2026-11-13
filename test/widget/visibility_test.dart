import 'package:binugi/app.dart';
import 'package:binugi/theme/app_theme.dart';
import 'package:binugi/ui/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'design_test.dart' show Ctx, seed, pumpApp, settle, scrollAll, screens;

/// 1.2.0 보기 쉬운 화면 규칙을 실제로 그려진 화면에서 확인:
/// 글자 16 이상 · 버튼 글자 17 이상 굵게 · 누를 곳 48 이상 · 누름/고름 표시
Iterable<RenderParagraph> paragraphs(WidgetTester tester) =>
    find.byType(RichText).evaluate().map((e) => e.renderObject).whereType<RenderParagraph>().where((r) => r.attached && r.text.toPlainText().trim().isNotEmpty);

double smallestFont(InlineSpan span, double inherited) {
  var size = inherited;
  if (span is TextSpan) {
    size = span.style?.fontSize ?? inherited;
    var min = size;
    for (final c in span.children ?? const <InlineSpan>[]) {
      final m = smallestFont(c, size);
      if (m < min) min = m;
    }
    return min;
  }
  return size;
}

Future<void> show(WidgetTester tester, Ctx c, String name, ThemeModeChoice theme) async {
  await pumpApp(tester, c, theme: theme, text: TextSizeChoice.normal);
  if (name != '홈') navKey.currentState!.push(MaterialPageRoute(builder: (_) => screens[name]!(c)));
  await settle(tester);
  await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
  await settle(tester);
}

void main() {
  for (final name in screens.keys) {
    testWidgets('[$name] 모든 글자 16 이상, 버튼 글자 17 이상·굵게, 누를 곳 48 이상', (tester) async {
      tester.view.physicalSize = const Size(390, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = await seed(tester);
      await show(tester, c, name, ThemeModeChoice.light);
      final small = <String>[];
      for (final r in paragraphs(tester)) {
        // 3D 그림(이모지 대체 글자)은 그림이라 제외
        final size = smallestFont(r.text, 14);
        if (size < 16) small.add('"${r.text.toPlainText()}" ${size}sp');
      }
      expect(small, isEmpty, reason: '16보다 작은 글자: $small');

      for (final b in find.byType(BigButton).evaluate()) {
        final box = b.renderObject as RenderBox;
        if (!box.hasSize) continue;
        expect(box.size.height, greaterThanOrEqualTo(52));
        expect(box.size.width, greaterThanOrEqualTo(48));
        final label = find.descendant(of: find.byWidget(b.widget), matching: find.byType(Text)).evaluate().map((e) => e.widget as Text).last;
        expect(label.style!.fontSize, greaterThanOrEqualTo(17), reason: '버튼 "${label.data}"');
        expect(label.style!.fontWeight!.value, greaterThanOrEqualTo(FontWeight.w700.value), reason: '버튼 "${label.data}" 굵게');
      }
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await tester.pump(const Duration(seconds: 6));
    });
  }

  for (final theme in ThemeModeChoice.values) {
    testWidgets('[${theme.name}] 큰 버튼 글자 대비 7:1 이상 (그려진 색으로)', (tester) async {
      tester.view.physicalSize = const Size(390, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = await seed(tester);
      for (final name in ['홈', '설정', '판매 자세히', '폐기 자세히', '진행 현황']) {
        await show(tester, c, name, theme);
        await scrollAll(tester);
        for (final b in find.byType(BigButton).evaluate()) {
          final w = b.widget as BigButton;
          if (w.onTap == null) continue; // 누를 수 없는 버튼은 제외
          final fill = find.descendant(of: find.byWidget(w), matching: find.byType(Container)).evaluate().map((e) => e.widget as Container).last;
          final bg = (fill.decoration as BoxDecoration).color!;
          final label = find.descendant(of: find.byWidget(w), matching: find.byType(Text)).evaluate().map((e) => e.widget as Text).last;
          final r = contrastRatio(label.style!.color!, bg);
          expect(r, greaterThanOrEqualTo(7), reason: '[$name] "${w.label}" 대비 ${r.toStringAsFixed(2)}');
        }
      }
      await tester.pump(const Duration(seconds: 6));
    });
  }

  testWidgets('누르는 동안 버튼 색이 확실히 바뀌고, 키보드(Tab)로 고르면 또렷한 띠 + Enter로 누름', (tester) async {
    var taps = 0;
    final c = await seed(tester);
    for (final theme in ThemeModeChoice.values) {
      await pumpApp(tester, c, theme: theme, text: TextSizeChoice.normal);
      navKey.currentState!.push(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: BigButton(label: '저장', onTap: () => taps++),
            ),
          ),
        ),
      );
      await settle(tester);
      final p = AppPalette.of(theme);
      Color fill() =>
          (find.descendant(of: find.byType(BigButton), matching: find.byType(Container)).evaluate().last.widget as Container).decoration is BoxDecoration
          ? ((find.descendant(of: find.byType(BigButton), matching: find.byType(Container)).evaluate().last.widget as Container).decoration as BoxDecoration)
                .color!
          : Colors.transparent;
      expect(fill(), p.primary);
      final g = await tester.startGesture(tester.getCenter(find.byType(BigButton)));
      await tester.pump(const Duration(milliseconds: 200));
      expect(fill(), p.pressedFill(p.primary), reason: '누르는 중');
      expect(contrastRatio(fill(), p.primary), greaterThan(1.3), reason: '눈에 띄게 다름');
      await g.up();
      await tester.pump(const Duration(milliseconds: 200));

      // 키보드로 고르기
      Border? ring() {
        for (final e in find.descendant(of: find.byType(BigButton), matching: find.byType(DecoratedBox)).evaluate()) {
          final d = (e.widget as DecoratedBox).decoration;
          if (d is BoxDecoration && d.border is Border && (d.border as Border).top.color == p.focus) return d.border as Border;
        }
        return null;
      }

      expect(ring(), isNull, reason: '손가락으로 누를 때는 띠 없음');
      final before = taps;
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(ring(), isNotNull, reason: '고르면 띠');
      expect(ring()!.top.width, greaterThanOrEqualTo(3));
      expect(contrastRatio(p.focus, p.background), greaterThanOrEqualTo(3), reason: '띠가 배경에서 또렷함');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 200));
      expect(taps, before + 1, reason: 'Enter로 누름');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    }
  });

  testWidgets('위험한 일(모두 지우기) 확인 버튼은 분명한 빨강', (tester) async {
    final c = await seed(tester);
    for (final theme in ThemeModeChoice.values) {
      await pumpApp(tester, c, theme: theme, text: TextSizeChoice.normal);
      await settle(tester);
      confirmOnce(navKey.currentState!.overlay!.context, title: '모두 지울까요?', message: '되돌릴 수 없어요', okLabel: '지우기', danger: true);
      await tester.pump(const Duration(milliseconds: 300));
      final b = tester.widget<BigButton>(find.widgetWithText(BigButton, '지우기'));
      final p = AppPalette.of(theme);
      expect(b.color, p.discard);
      expect(p.discard.r, greaterThan(p.discard.g * 3), reason: '빨강');
      expect(p.discard.r, greaterThan(p.discard.b * 3), reason: '빨강');
      await tester.tap(find.text('아니요'));
      await tester.pump(const Duration(milliseconds: 300));
    }
  });
}
