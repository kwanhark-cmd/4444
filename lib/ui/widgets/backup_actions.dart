import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/errors.dart';
import '../../core/platform.dart';
import '../../services/media_picker.dart';
import '../../state/app_state.dart';
import '../keys.dart';
import 'common.dart';

/// 안드로이드에서 앱 밖에 저장하지 않았을 때 보여 주는 경고
const backupNotSavedWarning =
    '백업 파일이 아직 앱 안에만 있어요. 안드로이드는 앱을 지우면 앱 안의 백업도 함께 지워져요.\n\n'
    '"저장할 곳 고르기"를 눌러 다운로드 폴더나 구글 드라이브에 저장해 주세요.';

/// "백업 파일 만들기": 비밀번호 → 백업 파일 만들기 → 앱 밖에 저장.
/// 안드로이드는 앱 밖(다운로드 폴더·드라이브)에 저장해야 앱을 지워도 남아요.
/// 앱을 지워도 남는 곳에 저장했으면 true.
Future<bool> makeBackupFile(BuildContext context) async {
  final s = context.read<AppState>();
  final picker = context.read<MediaPicker>();
  final pw = await askText(context, title: '백업 비밀번호', hint: '4글자 이상 · 꼭 기억해 두세요');
  if (pw == null || !context.mounted) return false;
  try {
    final f = await s.backup.createFile(pw, appVersion: appVersion);
    var saved = await picker.saveCopyOutside(f);
    if (!isAndroidDevice) {
      // 컴퓨터: 앱 자료 폴더는 앱을 지워도 남으므로, 폴더를 고르지 않으면 그 자리에 둡니다.
      final where = saved ?? f.path;
      await Clipboard.setData(ClipboardData(text: where));
      showMessage('백업을 만들었어요 (위치 복사됨): $where');
      return true;
    }
    if (saved == null && context.mounted) {
      final again = await confirmOnce(context, title: '아직 휴대폰에 저장하지 않았어요', message: backupNotSavedWarning, okLabel: '저장할 곳 고르기');
      if (again) saved = await picker.saveCopyOutside(f);
    }
    if (saved == null) {
      showMessage('백업 파일을 앱 밖에 저장하지 않았어요. 앱을 지우기 전에 꼭 다시 해 주세요.');
      return false;
    }
    showMessage('백업 파일을 앱 밖에 저장했어요: $saved · 앱을 지워도 이 파일은 남아요. 비밀번호를 꼭 기억해 두세요.');
    return true;
  } on UserFacingException catch (e) {
    showMessage(e.message);
    return false;
  } catch (e, st) {
    await showFailure(null, stage: '저장', message: '백업을 만들지 못했어요. 저장 공간을 확인해 주세요.', error: e, stack: st, onRetry: () => _again(makeBackupFile));
    return false;
  }
}

/// "백업에서 되살리기": 백업 파일 고르기 → 두 번 확인 → 비밀번호 → 되살리기. 되살렸으면 true.
/// 새로 설치한 앱(첫 실행 화면)에서도 씁니다.
Future<bool> restoreFromBackupFile(BuildContext context) async {
  final s = context.read<AppState>();
  final path = await context.read<MediaPicker>().pickBackupFile();
  if (path == null || !context.mounted) return false;
  final ok = await confirmTwice(context, title: '백업에서 되살리기', first: '지금 기기의 물건 목록이 백업 내용으로 바뀌어요.', second: '지금 자료는 사라져요. 계속할까요?', okLabel: '되살리기');
  if (!ok || !context.mounted) return false;
  final pw = await askText(context, title: '백업 비밀번호');
  if (pw == null) return false;
  try {
    await s.backup.restoreBytes(await File(path).readAsBytes(), pw);
    await s.reloadAfterRestore();
    showMessage('백업에서 되살렸어요. 새로 설치한 앱이면 AI 열쇠와 지메일 연결은 다시 해 주세요.');
    return true;
  } on UserFacingException catch (e) {
    await showFailure(null, stage: '백업', message: e.message, onRetry: () => _again(restoreFromBackupFile));
    return false;
  } catch (e, st) {
    await showFailure(null, stage: '백업', message: '되살리지 못했어요. 파일이 맞는지 확인해 주세요.', error: e, stack: st, onRetry: () => _again(restoreFromBackupFile));
    return false;
  }
}

/// "다시 시도": 그때 살아 있는 화면으로 다시 실행
Future<void> _again(Future<bool> Function(BuildContext) run) async {
  final c = liveContext();
  if (c != null) await run(c);
}
