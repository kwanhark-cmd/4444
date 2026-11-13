import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/logger.dart';
import '../../core/platform.dart';
import '../../services/media_picker.dart';
import '../../state/app_state.dart';
import '../keys.dart';
import 'common.dart';

/// 받침이 있으면 "을", 없으면 "를" (예: 영상을, 기록을, 사진을 / 파일을)
String eulReul(String word) {
  if (word.isEmpty) return '을';
  final c = word.codeUnitAt(word.length - 1);
  if (c < 0xAC00 || c > 0xD7A3) return '을';
  return (c - 0xAC00) % 28 == 0 ? '를' : '을';
}

/// 안드로이드 화면에 미리 보여 주는 저장 위치 안내
const exportWhereAndroid = '다 만들면 저장 화면이 열려요. 다운로드 폴더나 구글 드라이브를 고르면 휴대폰에서 바로 꺼낼 수 있고, 앱을 지워도 남아요.';

/// 안드로이드 설정 → 자료 관리의 내보내기 안내
const exportSettingsAndroid =
    '타임랩스 영상·움직이는 그림, 사연, 디지털 기록, 문제 신고 기록을 만들면 저장 화면이 열려요. '
    '다운로드 폴더나 구글 드라이브를 고르세요. 그래야 휴대폰에서 꺼낼 수 있고 앱을 지워도 남아요.';

/// 안드로이드에서 저장 화면을 취소했을 때 알림 (앱을 지우면 사라진다는 점을 분명히)
String exportNotSavedMessage(String what) => '$what${eulReul(what)} 앱 밖에 저장하지 않았어요. 지금은 앱 안에만 있어서 휴대폰에서 꺼낼 수 없고, 앱을 지우면 함께 지워져요.';

/// 안드로이드에서 앱 밖에 저장했을 때 알림
String exportSavedMessage(String what, String where) => '$what${eulReul(what)} 앱 밖에 저장했어요: $where · 앱을 지워도 이 파일은 남아요.';

/// 내보낸 파일(타임랩스 MP4·GIF, 사연, 디지털 기록, 문제 신고 기록)을 앱 밖에 저장합니다.
///
/// 안드로이드: 백업 파일과 같은 시스템 저장 화면(다운로드 폴더·드라이브 등)을 열고, 결과를 알림줄로 알려요.
/// 컴퓨터: 아무것도 하지 않고 null — 내보내기 폴더는 앱을 지워도 남으므로 지금처럼 그 폴더에 둡니다.
///
/// [what]은 알림에 쓰는 이름(예: "타임랩스 영상"). 안드로이드에서 앱 밖에 저장했으면 true, 취소·실패면 false.
/// [note]가 있으면 알림 끝에 덧붙여요(예: "기록은 복사도 해 두었어요").
Future<bool?> saveExportOutside(BuildContext? context, File file, {required String what, String mime = 'application/octet-stream', String note = ''}) async {
  if (!isAndroidDevice) return null;
  final c = liveContext(context);
  if (c == null) return false;
  final picker = c.read<MediaPicker>();
  try {
    final saved = await picker.saveCopyOutside(file, mime: mime);
    if (saved == null) {
      // 알림줄의 "저장할 곳 고르기"로 바로 다시 할 수 있어요.
      showMessage(
        _with(exportNotSavedMessage(what), note),
        actionLabel: '저장할 곳 고르기',
        onAction: () => saveExportOutside(null, file, what: what, mime: mime, note: note),
      );
      return false;
    }
    showMessage(_with(exportSavedMessage(what, saved), note));
    return true;
  } catch (e, st) {
    log.error('[내보내기] 앱 밖 저장 실패', e, st);
    showMessage(_with('$what${eulReul(what)} 앱 밖에 저장하지 못했어요. 다시 해 주세요. (앱 안에는 있어요)', note));
    return false;
  }
}

/// 사연·디지털 기록 폴더(사진·사연.txt·info.json)를 zip 하나로 묶어 앱 밖에 저장합니다 (안드로이드만).
/// 안드로이드 저장 화면은 파일 하나만 받을 수 있어서 폴더를 묶어요. 컴퓨터는 null(폴더 그대로).
Future<bool?> saveBundleOutside(
  BuildContext context,
  Directory dir, {
  required String label,
  required String itemName,
  required String what,
  String note = '',
}) async {
  if (!isAndroidDevice) return null;
  final exports = context.read<AppState>().exports;
  final File zip;
  try {
    zip = await exports.zipBundle(dir, label: label, itemName: itemName);
  } catch (e, st) {
    log.error('[내보내기] 묶기 실패', e, st);
    showMessage('$what${eulReul(what)} 파일로 묶지 못했어요. 저장 공간을 확인하고 다시 해 주세요.');
    return false;
  }
  return saveExportOutside(null, zip, what: what, mime: 'application/zip', note: note);
}

String _with(String msg, String note) => note.isEmpty ? msg : '$msg $note';
