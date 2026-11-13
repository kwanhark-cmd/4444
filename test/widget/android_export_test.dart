import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:binugi/app.dart';
import 'package:binugi/core/platform.dart';
import 'package:binugi/data/models.dart';
import 'package:binugi/state/app_state.dart';
import 'package:binugi/ui/screens/discard_screen.dart';
import 'package:binugi/ui/screens/settings_screen.dart';
import 'package:binugi/ui/screens/timelapse_screen.dart';
import 'package:binugi/ui/widgets/export_actions.dart';
import 'package:binugi/ui/widgets/report.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// 안드로이드 내보내기 파일(타임랩스·사연·디지털 기록·문제 신고)은 백업과 같은 저장 화면으로 앱 밖에 저장
Future<AppState> setup(WidgetTester tester, FakePicker picker, {Future<void> Function(AppState s)? prepare}) async {
  tester.view.physicalSize = const Size(500, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  late AppState s;
  await tester.runAsync(() async {
    final (st, _) = await makeState();
    s = st;
    s.global.onboarded = true;
    if (prepare != null) await prepare(s);
    await s.refresh();
  });
  await tester.pumpWidget(BinugiApp(state: s, picker: picker, listenShares: false));
  await tester.pump(const Duration(milliseconds: 300));
  return s;
}

/// 진짜 파일 읽기·쓰기가 끝날 때까지 기다리며 화면 갱신
Future<void> waitFor(WidgetTester tester, bool Function() done, {int tries = 120}) async {
  for (var i = 0; i < tries && !done(); i++) {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

BuildContext appContext() => navKey.currentState!.overlay!.context;

Future<void> open(WidgetTester tester, Widget screen) async {
  navKey.currentState!.push(MaterialPageRoute(builder: (_) => screen));
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> addShots(AppState s, int n) async {
  for (var i = 0; i < n; i++) {
    final ph = await s.savePhoto(fakeJpeg(w: 320, h: 240, seed: i + 1));
    await s.repo.addShot(TimelapseShot(userId: s.uid, spot: '거실 창가', path: ph.photoPath, takenAt: DateTime(2026, 1, i + 1)));
  }
}

void main() {
  setUp(() => debugPretendAndroid = true);
  tearDown(() => debugPretendAndroid = null);

  test('을/를: 받침 따라', () {
    expect(eulReul('영상'), '을');
    expect(eulReul('사연'), '을');
    expect(eulReul('디지털 기록'), '을');
    expect(eulReul('타임랩스 움직이는 그림'), '을');
    expect(eulReul('파일'), '을');
    expect(eulReul('사진 묶음 파일 모아 두기'), '를');
    expect(exportNotSavedMessage('사연'), startsWith('사연을 앱 밖에 저장하지 않았어요'));
  });

  testWidgets('안드로이드: 내보낸 파일을 저장 화면으로 앱 밖에 저장', (tester) async {
    final picker = FakePicker()..saveOutsideAs = '타임랩스_거실.mp4';
    final s = await setup(tester, picker);
    late File f;
    await tester.runAsync(() async {
      f = File('${s.paths.exportTimelapse.path}/타임랩스_거실.mp4');
      await f.writeAsBytes(List.filled(500, 7));
    });
    bool? r;
    saveExportOutside(appContext(), f, what: '타임랩스 영상', mime: 'video/mp4').then((v) => r = v);
    await waitFor(tester, () => r != null);
    expect(r, isTrue);
    expect(picker.savedMimes.single, 'video/mp4');
    final outside = picker.savedOutside.single;
    expect(outside.path, isNot(startsWith(s.paths.root.path)), reason: '앱 폴더 밖');
    expect(outside.lengthSync(), 500);
    expect(find.text(exportSavedMessage('타임랩스 영상', '타임랩스_거실.mp4')), findsOneWidget);
    expect(find.textContaining('앱을 지워도 이 파일은 남아요'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('안드로이드: 저장 화면을 취소하면 "앱 밖에 저장하지 않았어요" + 다시 고르기', (tester) async {
    final picker = FakePicker(); // 저장 화면에서 취소
    final s = await setup(tester, picker);
    late File f;
    await tester.runAsync(() async {
      f = File('${s.paths.exportTimelapse.path}/타임랩스_거실.gif');
      await f.writeAsBytes(List.filled(300, 1));
    });
    bool? r;
    saveExportOutside(appContext(), f, what: '타임랩스 움직이는 그림', mime: 'image/gif').then((v) => r = v);
    await waitFor(tester, () => r != null);
    expect(r, isFalse);
    expect(picker.savedOutside, isEmpty);
    expect(find.text(exportNotSavedMessage('타임랩스 움직이는 그림')), findsOneWidget);
    expect(find.textContaining('앱을 지우면 함께 지워져요'), findsOneWidget);
    // 알림줄의 "저장할 곳 고르기"로 다시 → 이번에는 저장
    picker.saveOutsideAs = '타임랩스_다시.gif';
    await tester.pump(const Duration(seconds: 1)); // 알림줄이 다 올라올 때까지
    await tester.tap(find.text('저장할 곳 고르기'));
    await waitFor(tester, () => picker.savedOutside.isNotEmpty);
    expect(picker.saveOutsideCalls, 2);
    expect(picker.savedOutside.single.uri.pathSegments.last, '타임랩스_다시.gif');
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('안드로이드: 저장 화면이 실패해도 앱은 멈추지 않고 알림', (tester) async {
    final picker = _BrokenPicker();
    final s = await setup(tester, picker);
    late File f;
    await tester.runAsync(() async {
      f = File('${s.paths.exportReports.path}/문제신고_1.txt');
      await f.writeAsString('기록');
    });
    bool? r;
    saveExportOutside(appContext(), f, what: '문제 신고 기록').then((v) => r = v);
    await waitFor(tester, () => r != null);
    expect(r, isFalse);
    expect(find.textContaining('앱 밖에 저장하지 못했어요'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('컴퓨터: 저장 화면 없이 지금처럼 내보내기 폴더에 둠', (tester) async {
    debugPretendAndroid = false;
    final picker = FakePicker()..saveOutsideAs = 'x.mp4';
    final s = await setup(tester, picker);
    late File f;
    await tester.runAsync(() async {
      f = File('${s.paths.exportTimelapse.path}/x.mp4');
      await f.writeAsBytes([1, 2, 3]);
    });
    expect(await saveExportOutside(appContext(), f, what: '타임랩스 영상'), isNull);
    expect(picker.saveOutsideCalls, 0);
  });

  testWidgets('안드로이드 타임랩스 GIF·MP4: 만들고 나면 저장 화면으로 앱 밖에 저장', (tester) async {
    final picker = FakePicker()..saveOutsideAs = '타임랩스.gif';
    await setup(tester, picker, prepare: (s) => addShots(s, 2));
    await open(tester, const TimelapsePlayer(spot: '거실 창가'));
    await waitFor(tester, () => find.text('움직이는 그림(GIF)으로 저장').evaluate().isNotEmpty);
    expect(find.text(exportWhereAndroid), findsOneWidget, reason: '미리 안내');
    expect(find.textContaining('앱용 폴더'), findsNothing);

    await tester.ensureVisible(find.text('움직이는 그림(GIF)으로 저장'));
    await tester.tap(find.text('움직이는 그림(GIF)으로 저장'));
    await waitFor(tester, () => picker.savedOutside.isNotEmpty, tries: 400);
    expect(picker.savedMimes.single, 'image/gif');
    expect(picker.savedOutside.single.lengthSync(), greaterThan(100));
    await waitFor(tester, () => find.textContaining('앱 밖에 저장했어요').evaluate().isNotEmpty);
    expect(find.text(exportSavedMessage('타임랩스 움직이는 그림', '타임랩스.gif')), findsOneWidget);

    picker.saveOutsideAs = '타임랩스_세로.mp4';
    await tester.ensureVisible(find.text('세로 9:16'));
    await tester.tap(find.text('세로 9:16'));
    await waitFor(tester, () => picker.savedOutside.length == 2, tries: 600);
    expect(picker.savedMimes.last, 'video/mp4');
    final mp4 = picker.savedOutside.last.readAsBytesSync();
    expect(String.fromCharCodes(mp4.sublist(4, 8)), 'ftyp', reason: '진짜 MP4');
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('안드로이드 디지털 기록: 사진·사연을 zip 하나로 묶어 앱 밖에 저장', (tester) async {
    final picker = FakePicker()..saveOutsideAs = '디지털기록_여행 기념품.zip';
    late Item it;
    await setup(
      tester,
      picker,
      prepare: (s) async {
        final ph = await s.savePhoto(fakeJpeg(w: 200, h: 150));
        it = await s.addItem(name: '여행 기념품', photo: ph);
        it.story = '제주도에서 산 기념품';
        await s.saveItem(it);
        await s.decide(it, Decision.discard);
      },
    );
    await open(tester, DiscardDetailScreen(itemId: it.id!));
    await waitFor(tester, () => find.text('사진·사연 남기고 버리기').evaluate().isNotEmpty);
    await tester.ensureVisible(find.text('사진·사연 남기고 버리기'));
    await tester.tap(find.text('사진·사연 남기고 버리기'));
    await waitFor(tester, () => picker.savedOutside.isNotEmpty);
    expect(picker.savedMimes.single, 'application/zip');
    final zip = ZipDecoder().decodeBytes(picker.savedOutside.single.readAsBytesSync());
    final names = zip.files.map((f) => f.name).toList();
    expect(names, containsAll(['디지털기록_여행 기념품/사진.jpg', '디지털기록_여행 기념품/사연.txt', '디지털기록_여행 기념품/info.json']));
    final story = utf8.decode(zip.findFile('디지털기록_여행 기념품/사연.txt')!.content);
    expect(story, contains('제주도에서 산 기념품'));
    await waitFor(tester, () => find.textContaining('디지털 기록을 앱 밖에 저장했어요').evaluate().isNotEmpty);
    expect(find.textContaining('디지털 기록을 앱 밖에 저장했어요'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('안드로이드 사연: zip으로 묶어 앱 밖에 저장 (취소하면 앱 안에만 있다고 알림)', (tester) async {
    final picker = FakePicker();
    late AppState st;
    late Item it;
    st = await setup(
      tester,
      picker,
      prepare: (s) async {
        final ph = await s.savePhoto(fakeJpeg(w: 200, h: 150));
        it = await s.addItem(name: '커피 머신', photo: ph);
      },
    );
    late Directory dir;
    await tester.runAsync(() async => dir = await st.saveStory(it, '결혼 10주년 선물'));
    bool? r;
    saveBundleOutside(appContext(), dir, label: '사연', itemName: it.name, what: '사연').then((v) => r = v);
    await waitFor(tester, () => r != null);
    expect(r, isFalse);
    expect(picker.savedMimes.single, 'application/zip');
    expect(find.text(exportNotSavedMessage('사연')), findsOneWidget);
    expect(File('${dir.parent.path}/사연_커피 머신.zip').existsSync(), isTrue);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('안드로이드 문제 신고: 복사 + 저장 화면으로 앱 밖에도 저장', (tester) async {
    final picker = FakePicker()..saveOutsideAs = '문제신고.txt';
    await setup(tester, picker);
    File? f;
    var done = false;
    reportProblem().then((v) {
      f = v;
      done = true;
    });
    await waitFor(tester, () => done);
    expect(f, isNotNull);
    expect(picker.savedMimes.single, 'text/plain');
    expect(picker.savedOutside.single.readAsStringSync(), f!.readAsStringSync());
    expect(find.textContaining('문제 신고 기록을 앱 밖에 저장했어요'), findsOneWidget);
    expect(find.textContaining('복사도 해 두었어요'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('안드로이드 설정: 앱 안 폴더 위치 대신 저장 화면 안내', (tester) async {
    final s = await setup(tester, FakePicker());
    await open(tester, const SettingsScreen());
    await tester.scrollUntilVisible(find.text(exportSettingsAndroid), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text(exportSettingsAndroid), findsOneWidget);
    expect(find.text('내보내기 폴더 (위치 복사)'), findsNothing);
    expect(find.text(s.paths.exports.path), findsNothing);
  });
}

class _BrokenPicker extends FakePicker {
  @override
  Future<String?> saveCopyOutside(File file, {String mime = 'application/octet-stream'}) async => throw Exception('저장 화면 실패');
}
