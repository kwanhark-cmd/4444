import 'package:binugi/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 대비 검사 (1.2.0 보기 쉬운 화면: 글자는 7:1 이상 = WCAG AAA, 테두리·고름 띠는 3:1 이상)
void main() {
  for (final mode in ThemeModeChoice.values) {
    final p = AppPalette.of(mode);
    group('대비 검사 $mode', () {
      void check(String name, Color fg, Color bg, {double min = 7}) {
        test(name, () {
          final r = contrastRatio(fg, bg);
          expect(r, greaterThanOrEqualTo(min), reason: '$name 대비 ${r.toStringAsFixed(2)}');
        });
      }

      check('본문 글자/배경', p.onSurface, p.background);
      check('본문 글자/카드', p.onSurface, p.surface);
      check('흐린 글자(설명)/카드', p.muted, p.surface);
      check('흐린 글자(설명)/배경', p.muted, p.background);
      check('주요 버튼', p.onPrimary, p.primary);
      check('주요 버튼 (자동 글자색)', p.onFill(p.primary), p.primary);
      check('강조 버튼', p.onAccent, p.accent);
      check('지금 쓰는 것(파랑) 버튼', p.onCategory, p.use);
      check('판매(초록) 버튼', p.onCategory, p.sell);
      check('폐기(빨강) 버튼', p.onCategory, p.discard);
      check('진행 중(보라)', Colors.white, p.progress);
      check('확인 필요(노랑)', p.onAttention, p.attention);
      check('흐린 버튼 (자동 글자색)', p.onFill(p.muted), p.muted);
      check('글자 버튼(주요색 글자)/카드', p.primary, p.surface);
      check('글자 버튼(주요색 글자)/배경', p.primary, p.background);
      check('폐기 빨강 글자/카드', p.ink(p.discard), p.surface);
      check('진행 보라 글자/카드', p.ink(p.progress), p.surface);
      check('알림줄', Colors.white, const Color(0xFF263238));
      check('알림줄 버튼', const Color(0xFFFFD54F), const Color(0xFF263238));
      check('테두리 버튼 테두리/카드', p.outline, p.surface, min: 4.5);
      check('테두리 버튼 테두리/배경', p.outline, p.background, min: 4.5);
      check('키보드로 고른 띠/배경', p.focus, p.background, min: 3);
      check('키보드로 고른 띠/카드', p.focus, p.surface, min: 3);
      if (p.buttonEdge != null) check('색 버튼 테두리/배경', p.buttonEdge!, p.background, min: 3);
      check('누르고 있는 주요 버튼', p.onFill(p.pressedFill(p.primary)), p.pressedFill(p.primary), min: 4.5);
    });
  }

  test('모든 색 테마(바다·흙·먹·호수)의 주요 버튼도 7:1 이상', () {
    for (final mode in [ThemeModeChoice.light, ThemeModeChoice.dark]) {
      for (final key in colorThemes.keys) {
        final p = AppPalette.of(mode, key);
        final r = contrastRatio(p.onPrimary, p.primary);
        expect(r, greaterThanOrEqualTo(7), reason: '$mode $key ${r.toStringAsFixed(2)}');
        expect(contrastRatio(p.primary, p.surface), greaterThanOrEqualTo(7), reason: '$mode $key 주요색 글자');
      }
    }
  });

  test('어떤 색을 넘겨도 큰 버튼 바탕은 글자와 7:1 이상 (strongFill)', () {
    for (final mode in ThemeModeChoice.values) {
      final p = AppPalette.of(mode);
      for (final c in const [Color(0xFFB34700), Color(0xFFB71C1C), Color(0xFF1565C0), Color(0xFFFFD54F), Color(0xFF9EC1F7), Color(0xFF888888), Colors.white]) {
        final f = p.strongFill(c);
        expect(contrastRatio(p.onFill(f), f), greaterThanOrEqualTo(7), reason: '$mode $c → $f');
      }
    }
  });

  test('분류 색 고정: 파랑·초록·빨강, 상태색과 겹치지 않음', () {
    for (final p in [AppPalette.light, AppPalette.dark, AppPalette.highContrast]) {
      expect(p.use.b > p.use.r, isTrue);
      expect(p.sell.g > p.sell.r && p.sell.g > p.sell.b, isTrue);
      expect(p.discard.r > p.discard.g * 3 && p.discard.r > p.discard.b * 3, isTrue, reason: '위험(폐기·지우기)은 분명한 빨강');
      expect({p.use, p.sell, p.discard, p.progress, p.attention}.length, 5);
    }
  });

  test('움직임 줄이기: 모든 시간이 0', () {
    const m = AppMotion(true);
    expect([m.fast, m.normal, m.slow, m.celebrate].every((d) => d == Duration.zero), isTrue);
    expect(const AppMotion(false).normal, greaterThan(Duration.zero));
  });

  test('버튼·글자 크기 기준', () {
    expect(AppSizes.buttonMinHeight, greaterThanOrEqualTo(52));
    expect(AppSizes.touchMin, greaterThanOrEqualTo(48));
    expect(AppText.button, greaterThanOrEqualTo(17));
    expect(AppText.buttonWeight.value, greaterThanOrEqualTo(FontWeight.w700.value));
    expect(AppText.caption, greaterThanOrEqualTo(16));
    expect(AppText.body, greaterThanOrEqualTo(16));
    expect(AppSizes.outlineWidth, greaterThanOrEqualTo(2));
  });

  for (final mode in ThemeModeChoice.values) {
    test('테마 규칙 $mode: 버튼 높이·글자·테두리·누름 표시·글자 크기', () {
      final t = buildTheme(mode);
      final p = AppPalette.of(mode);
      const none = <WidgetState>{};
      final styles = {
        'Elevated': t.elevatedButtonTheme.style!,
        'Filled': t.filledButtonTheme.style!,
        'Outlined': t.outlinedButtonTheme.style!,
        'Text': t.textButtonTheme.style!,
      };
      for (final MapEntry(key: name, value: s) in styles.entries) {
        expect(s.minimumSize!.resolve(none)!.height, greaterThanOrEqualTo(52), reason: '$name 높이');
        expect(s.minimumSize!.resolve(none)!.width, greaterThanOrEqualTo(48), reason: '$name 폭');
        final label = s.textStyle!.resolve(none)!;
        expect(label.fontSize, greaterThanOrEqualTo(17), reason: '$name 글자');
        expect(label.fontWeight!.value, greaterThanOrEqualTo(FontWeight.w700.value), reason: '$name 굵게');
        expect(s.tapTargetSize, MaterialTapTargetSize.padded);
        final pressed = s.overlayColor!.resolve({WidgetState.pressed})!;
        expect(pressed.a, greaterThanOrEqualTo(0.2), reason: '$name 누르면 확실히 보임');
        final focus = s.side!.resolve({WidgetState.focused})!;
        expect(focus.width, greaterThanOrEqualTo(3), reason: '$name 고르면 띠');
        expect(focus.color, p.focus);
      }
      // 채운 버튼: 7:1
      final filled = styles['Filled']!;
      expect(contrastRatio(filled.foregroundColor!.resolve(none)!, filled.backgroundColor!.resolve(none)!), greaterThanOrEqualTo(7));
      // 테두리 버튼: 2px, 또렷한 색
      final outlined = styles['Outlined']!;
      final side = outlined.side!.resolve(none)!;
      expect(side.width, greaterThanOrEqualTo(2));
      expect(contrastRatio(side.color, p.surface), greaterThanOrEqualTo(4.5));
      expect(contrastRatio(outlined.foregroundColor!.resolve(none)!, outlined.backgroundColor!.resolve(none)!), greaterThanOrEqualTo(7));
      // 글자 버튼
      final text = styles['Text']!;
      expect(contrastRatio(text.foregroundColor!.resolve(none)!, p.surface), greaterThanOrEqualTo(7));
      // 아이콘 버튼 48
      expect(t.iconButtonTheme.style!.minimumSize!.resolve(none)!.shortestSide, greaterThanOrEqualTo(48));
      expect(t.materialTapTargetSize, MaterialTapTargetSize.padded);
      // 글자 크기: 본문·설명 모두 16 이상
      final tt = t.textTheme;
      for (final MapEntry(key: name, value: st) in {
        'bodyLarge': tt.bodyLarge,
        'bodyMedium': tt.bodyMedium,
        'bodySmall': tt.bodySmall,
        'titleSmall': tt.titleSmall,
        'labelLarge': tt.labelLarge,
        'labelMedium': tt.labelMedium,
        'labelSmall': tt.labelSmall,
      }.entries) {
        expect(st!.fontSize, greaterThanOrEqualTo(16), reason: name);
        expect(contrastRatio(st.color!, p.surface), greaterThanOrEqualTo(7), reason: '$name 대비');
      }
      expect(t.listTileTheme.subtitleTextStyle!.fontSize, greaterThanOrEqualTo(16));
      // 입력칸 테두리 2px 또렷, 고르면 3px
      final input = t.inputDecorationTheme;
      expect((input.enabledBorder as OutlineInputBorder).borderSide.width, greaterThanOrEqualTo(2));
      expect(contrastRatio((input.enabledBorder as OutlineInputBorder).borderSide.color, p.surface), greaterThanOrEqualTo(4.5));
      expect((input.focusedBorder as OutlineInputBorder).borderSide.width, greaterThanOrEqualTo(3));
    });
  }
}
