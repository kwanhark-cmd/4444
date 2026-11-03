// 보고서용 화면 사진 만들기:  flutter test test_screens --update-goldens
import 'dart:io';

import 'package:binugi/app.dart';
import 'package:binugi/data/models.dart';
import 'package:binugi/theme/app_theme.dart';
import 'package:binugi/ui/screens/classify_screen.dart';
import 'package:binugi/ui/screens/discard_screen.dart';
import 'package:binugi/ui/screens/progress_screen.dart';
import 'package:binugi/ui/screens/sell_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/helpers.dart';

Future<void> _loadFonts() async {
  final ko = FontLoader('NotoSansKR')
    ..addFont(rootBundle.load('assets/fonts/NotoSansKR-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/NotoSansKR-Bold.ttf'));
  await ko.load();
  final sdk = Platform.environment['FLUTTER_ROOT'] ?? '/opt/sdk/flutter';
  final icons = File('$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    final l = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
    await l.load();
  }
}

void main() {
  final shots = <String, Widget Function(Item sell, Item discard)>{
    '1_홈': (_, _) => const SizedBox.shrink(),
    '2_정리하기': (_, _) => const ClassifyScreen(),
    '3_판매도우미': (s, _) => SellDetailScreen(itemId: s.id!),
    '4_폐기도우미': (_, d) => DiscardDetailScreen(itemId: d.id!),
    '5_진행현황': (_, _) => const ProgressScreen(),
  };
  for (final theme in [ThemeModeChoice.light, ThemeModeChoice.dark]) {
    for (final e in shots.entries) {
      testWidgets('${e.key} ${theme.name}', (tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        late Item sell, discard;
        final c = await tester.runAsync(() async {
          await _loadFonts();
          final (s, _) = await makeState();
          final ph = await s.savePhoto(fakeJpeg(w: 600, h: 450, seed: 5));
          await s.addItem(
            name: '10년 된 커피 머신',
            condition: '잘 작동함',
            room: '주방',
            photo: ph,
            suggestion: Decision.sell,
            reason: '아직 쓸 만해 보여요. 팔면 다른 사람이 잘 쓸 수 있어요.',
          );
          sell = await s.addItem(name: '블루투스 스피커', condition: '잘 작동함', photo: ph);
          await s.decide(sell, Decision.sell);
          final l = await s.ai.writeListing(s.uid, s.user, sell);
          sell
            ..listingTitle = l.value.title
            ..listingBody = l.value.body
            ..listingCategory = l.value.category
            ..priceLow = l.value.priceLow
            ..priceHigh = l.value.priceHigh;
          await s.sales.startSelling(sell, price: l.value.priceHigh);
          discard = await s.addItem(name: '낡은 나무 의자', kind: '가구', photo: ph);
          await s.decide(discard, Decision.discard);
          final sold = await s.addItem(name: '겨울 패딩');
          await s.sales.startSelling(sold, price: 25000);
          await s.sales.setStatus(sold, SaleStatus.sold);
          s.user
            ..sido = '서울특별시'
            ..sigungu = '마포구';
          await s.saveUser();
          s.global
            ..onboarded = true
            ..theme = theme;
          for (final t in ['home', 'swipe', 'sell']) {
            await s.repo.setSetting(s.uid, 'tip_$t', '1');
          }
          await s.refresh();
          return s;
        });
        await tester.pumpWidget(BinugiApp(state: c!, picker: FakePicker(), listenShares: false));
        if (e.key != '1_홈') navKey.currentState!.push(MaterialPageRoute(builder: (_) => e.value(sell, discard)));
        for (var i = 0; i < 5; i++) {
          await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 150)));
          await tester.pump(const Duration(milliseconds: 300));
        }
        await tester.runAsync(() async {
          for (final el in find.byType(Image).evaluate()) {
            await precacheImage((el.widget as Image).image, el);
          }
        });
        await tester.pump(const Duration(milliseconds: 300));
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('../docs/화면/${e.key}_${theme.name}.png'));
        await tester.pump(const Duration(seconds: 6));
      });
    }
  }
}
