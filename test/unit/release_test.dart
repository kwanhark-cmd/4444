import 'dart:io';

import 'package:binugi/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// 배포 설정 점검: 서명 열쇠 없이, 안드로이드 APK도 Releases에, 안내 글 맨 위는 안드로이드 순서(백업 먼저)
void main() {
  final workflow = File('.github/workflows/build.yml').readAsStringSync();
  final head = File('.github/release_notes_head.md').readAsStringSync();

  test('빌드에 서명 열쇠(Secrets)를 쓰지 않고, 열쇠를 달라는 경고도 없음', () {
    expect(workflow, isNot(contains('secrets.')));
    expect(workflow.toUpperCase(), isNot(contains('KEYSTORE')));
    expect(workflow, isNot(contains('key.properties')));
    expect(workflow, isNot(contains('::warning::')));
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, isNot(contains('key.properties')));
    expect(gradle, contains('signingConfigs.getByName("debug")'));
  });

  test('안드로이드 APK를 Releases에서 빼지 않음 (네 가지 설치 파일 모두 올림)', () {
    expect(workflow, isNot(contains('rm -f dist/binugi-android.apk')));
    expect(workflow, isNot(contains('signing-kind')));
    for (final f in ['binugi-android.apk', 'binugi-windows-setup.exe', 'binugi-macos.zip', 'binugi-linux.tar.gz']) {
      expect(workflow, contains('dist/$f'));
    }
    expect(workflow, contains('fail_on_unmatched_files: true'));
  });

  test('새 버전 안내 글: 맨 위에 안드로이드 순서, 백업(앱 밖 저장)이 예전 앱 지우기보다 먼저', () {
    final cp = workflow.indexOf('cp .github/release_notes_head.md notes.md');
    final changes = workflow.indexOf('CHANGELOG.md >> notes.md');
    expect(cp, greaterThan(0));
    expect(changes, greaterThan(cp), reason: '바뀐 점은 설치 방법 아래');
    final firstLine = head.split('\n').firstWhere((l) => l.trim().isNotEmpty);
    expect(firstLine, contains('안드로이드'));
    final backup = head.indexOf('백업 파일 만들기');
    final outside = head.indexOf('다운로드 폴더나 구글 드라이브');
    final delete = head.indexOf('예전 앱 지우기');
    expect(backup, greaterThan(0));
    expect(outside, greaterThan(backup));
    expect(delete, greaterThan(outside), reason: '앱을 지우라는 말보다 백업이 먼저');
    expect(head.indexOf('백업에서 되살리기'), greaterThan(delete));
    expect(head, isNot(contains('덮어쓰기 설치하면')));
    expect(head, contains('■ 바뀐 점'), reason: '앱 안 안드로이드 창은 이 아래만 보여 줌');
  });

  test('문서에 서명 열쇠 등록 안내가 없고, 앱을 지우라는 말 앞에 항상 백업', () {
    for (final f in ['README.md', 'PROGRESS.md', 'BLOCKERS.md', 'CHANGELOG.md', 'docs/보고/수정보고.md', 'docs/검증/누락점검.md']) {
      final s = File(f).readAsStringSync();
      for (final line in s.split('\n')) {
        if (line.contains('~~')) continue; // 닫은 항목
        expect(line, isNot(contains('ANDROID_KEYSTORE')), reason: '$f: $line');
        expect(line, isNot(contains('Secrets에 넣')), reason: '$f: $line');
      }
    }
    final readme = File('README.md').readAsStringSync();
    expect(readme, contains('https://github.com/kwanhark-cmd/4444/releases'));
    final android = readme.substring(readme.indexOf('### 안드로이드 휴대폰'));
    expect(android.indexOf('백업 파일 만들기'), lessThan(android.indexOf('예전 앱 지우기')));
    expect(readme, isNot(contains('새 버전 설치 = 덮어쓰기')));
  });

  test('CHANGELOG에 지금 버전 부분이 있음 (Releases 안내 글에 들어감)', () {
    expect(File('CHANGELOG.md').readAsStringSync(), contains('\n## $appVersion\n'));
  });
}
