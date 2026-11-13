import 'dart:io';

import 'package:binugi/app.dart';
import 'package:binugi/core/platform.dart';
import 'package:binugi/services/update_service.dart';
import 'package:binugi/state/app_state.dart';
import 'package:binugi/ui/screens/onboarding_screen.dart';
import 'package:binugi/ui/widgets/backup_actions.dart';
import 'package:binugi/ui/widgets/update_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// 안드로이드 새 버전 방법: 백업 파일을 앱 밖에 저장 → 새 파일 내려받기 → 예전 앱 지우기 → 설치 → 되살리기
Future<AppState> setup(WidgetTester tester, FakePicker picker, {bool onboarded = true, int items = 0}) async {
  tester.view.physicalSize = const Size(500, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  late AppState s;
  await tester.runAsync(() async {
    final (st, _) = await makeState();
    s = st;
    s.global.onboarded = onboarded;
    for (var i = 0; i < items; i++) {
      await s.addItem(name: '물건 $i', room: '거실');
    }
  });
  await tester.pumpWidget(BinugiApp(state: s, picker: picker, listenShares: false));
  await tester.pump(const Duration(milliseconds: 300));
  return s;
}

/// 진짜 파일 읽기·쓰기(백업 만들기)가 끝날 때까지 기다리며 화면 갱신
Future<void> waitFor(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 80 && !done(); i++) {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

BuildContext appContext() => navKey.currentState!.overlay!.context;

Future<void> enterPassword(WidgetTester tester, String pw) async {
  await tester.enterText(find.byType(TextField), pw);
  await tester.tap(find.text('확인'));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUp(() => debugPretendAndroid = true);
  tearDown(() => debugPretendAndroid = null);

  final info = UpdateInfo(
    version: '9.0.0',
    notes: '- 화면이 더 보기 쉬워졌어요',
    assetName: 'binugi-android.apk',
    assetUrl: 'https://github.com/kwanhark-cmd/4444/releases/download/v9.0.0/binugi-android.apk',
    assetSize: 10,
  );

  testWidgets('안드로이드 백업 파일 만들기: 시스템 저장 화면으로 앱 밖에 저장', (tester) async {
    final picker = FakePicker()..saveOutsideAs = '비우기백업_테스트.binugi';
    final s = await setup(tester, picker, items: 2);
    bool? result;
    makeBackupFile(appContext()).then((v) => result = v);
    await settle(tester);
    await enterPassword(tester, '1234');
    await waitFor(tester, () => result != null);
    expect(result, isTrue);
    expect(picker.saveOutsideCalls, 1);
    final outside = picker.savedOutside.single;
    expect(outside.path, isNot(startsWith(s.paths.root.path)), reason: '앱 폴더 밖');
    expect(outside.lengthSync(), greaterThan(100));
    expect(find.textContaining('앱 밖에 저장했어요'), findsOneWidget);
    expect(find.textContaining('앱을 지워도 이 파일은 남아요'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('안드로이드 백업: 저장 화면을 취소하면 "앱을 지우면 함께 지워져요" 경고 + 다시 고르기', (tester) async {
    final picker = FakePicker(); // 저장 화면에서 취소
    await setup(tester, picker);
    bool? result;
    makeBackupFile(appContext()).then((v) => result = v);
    await settle(tester);
    await enterPassword(tester, '1234');
    await waitFor(tester, () => find.text('아직 휴대폰에 저장하지 않았어요').evaluate().isNotEmpty);
    expect(find.text(backupNotSavedWarning), findsOneWidget);
    // 다시 고르기 → 이번에는 저장
    picker.saveOutsideAs = '비우기백업_다시.binugi';
    await tester.tap(find.text('저장할 곳 고르기'));
    await waitFor(tester, () => result != null);
    expect(result, isTrue);
    expect(picker.saveOutsideCalls, 2);
    expect(picker.savedOutside.single.uri.pathSegments.last, '비우기백업_다시.binugi');
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('안드로이드 백업: 끝까지 저장하지 않으면 실패로 알림', (tester) async {
    final picker = FakePicker();
    await setup(tester, picker);
    bool? result;
    makeBackupFile(appContext()).then((v) => result = v);
    await settle(tester);
    await enterPassword(tester, '1234');
    await waitFor(tester, () => find.text('아직 휴대폰에 저장하지 않았어요').evaluate().isNotEmpty);
    await tester.tap(find.text('아니요'));
    await waitFor(tester, () => result != null);
    await settle(tester);
    expect(result, isFalse);
    expect(find.textContaining('앱을 지우기 전에 꼭 다시 해 주세요'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('안드로이드 새 버전 창: 덮어쓰기 설치 없음, 백업이 첫 단계, 내려받기는 브라우저로', (tester) async {
    final opened = <Uri>[];
    final saved = openInBrowser;
    openInBrowser = (u) async {
      opened.add(u);
      return true;
    };
    addTearDown(() => openInBrowser = saved);
    final picker = FakePicker()..saveOutsideAs = '비우기백업_업데이트.binugi';
    final s = await setup(tester, picker);
    showUpdateDialog(appContext(), info);
    await settle(tester);

    // 순서: 백업(앱 밖 저장)이 맨 먼저, 예전 앱 지우기는 백업 확인 뒤
    expect(androidUpdateSteps.first, contains('백업 파일 만들기'));
    expect(androidUpdateSteps.first, contains('앱 밖'));
    final del = androidUpdateSteps.indexWhere((t) => t.contains('예전 앱 지우기'));
    expect(del, greaterThan(0));
    expect(androidUpdateSteps[del], contains('백업 파일이'));
    expect(androidUpdateSteps.last, contains('백업에서 되살리기'));
    for (final t in androidUpdateSteps) {
      expect(find.text(t), findsOneWidget);
    }
    expect(find.textContaining('덮어 설치할 수 없어요'), findsOneWidget);
    expect(find.textContaining('그대로 남아요'), findsNothing, reason: '안드로이드는 "자료 그대로" 약속 없음');
    expect(find.text('내려받아 설치'), findsNothing, reason: '앱 안에서 APK 설치 안 함');
    expect(find.textContaining('보기 쉬워졌어요'), findsOneWidget, reason: '바뀐 점도 보여 줌');

    // 백업 없이 내려받기 → 한 번 더 확인
    await tester.tap(find.text('2. 내려받기 화면 열기'));
    await settle(tester);
    expect(find.text('백업 파일은 만들었나요?'), findsOneWidget);
    await tester.tap(find.text('아니요'));
    await settle(tester);
    expect(opened, isEmpty);

    // 1. 백업 파일 만들기 → 앱 밖에 저장
    await tester.tap(find.text('1. 백업 파일 만들기'));
    await settle(tester);
    await enterPassword(tester, '1234');
    await waitFor(tester, () => find.text('✓ 백업 파일 저장함').evaluate().isNotEmpty);
    expect(picker.savedOutside, hasLength(1));

    // 2. 내려받기 화면 열기 → 확인 없이 바로 브라우저
    await tester.tap(find.text('2. 내려받기 화면 열기'));
    await settle(tester);
    expect(opened.single.toString(), info.assetUrl);
    expect(find.text('백업 파일은 만들었나요?'), findsNothing);
    expect(Directory('${s.paths.root.path}/업데이트').existsSync(), isFalse, reason: '앱 안으로 APK를 내려받지 않음');
    await tester.tap(find.text('닫기'));
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('안드로이드 새 버전 창: 설치 파일 주소가 없으면 공개 내려받기 화면', (tester) async {
    final opened = <Uri>[];
    final saved = openInBrowser;
    openInBrowser = (u) async {
      opened.add(u);
      return true;
    };
    addTearDown(() => openInBrowser = saved);
    await setup(tester, FakePicker());
    await openDownloadPage(UpdateInfo(version: '9.0.0', notes: ''));
    expect(opened.single.toString(), 'https://github.com/kwanhark-cmd/4444/releases/latest');
    expect(releasesPage, 'https://github.com/kwanhark-cmd/4444/releases/latest');
  });

  testWidgets('안드로이드 설정 업데이트 칸: "그대로 남아요" 대신 순서 안내', (tester) async {
    await setup(tester, FakePicker());
    navKey.currentState!.push(MaterialPageRoute(builder: (_) => const Scaffold(body: UpdateCard())));
    await settle(tester);
    expect(find.textContaining('백업 → 예전 앱 지우기 → 새로 설치'), findsOneWidget);
    expect(find.textContaining('그대로 남아요'), findsNothing);
  });

  testWidgets('새로 설치한 앱 첫 화면에서 바로 "백업에서 되살리기"', (tester) async {
    final picker = FakePicker();
    await setup(tester, picker, onboarded: false);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    await tester.scrollUntilVisible(find.text('백업에서 되살리기'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('백업에서 되살리기'), findsOneWidget);
    // 파일을 고르지 않으면 아무 일도 없음
    await tester.tap(find.text('백업에서 되살리기'));
    await settle(tester);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
