import 'dart:io';

import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/logger.dart';
import '../../core/platform.dart';
import '../../state/app_state.dart';
import '../keys.dart';
import 'common.dart';
import 'export_actions.dart';

/// 문제 신고: 기록(사진·열쇠 제외)을 파일로 저장하고 복사. 설정 맨 위와 모든 오류 창에서 사용.
Future<File?> reportProblem() async {
  final c = liveContext();
  if (c == null) return null;
  final s = c.read<AppState>();
  try {
    final text = await log.exportText(appVersion: appVersion, platform: '${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
    final f = await s.exports.exportReport(text, DateTime.now());
    await Clipboard.setData(ClipboardData(text: text));
    if (isAndroidDevice) {
      // 안드로이드: 앱 전용 폴더의 파일은 꺼낼 수 없어서, 저장 화면으로 앱 밖에도 저장 (복사는 이미 됨)
      await saveExportOutside(null, f, what: '문제 신고 기록', mime: 'text/plain', note: '기록은 복사도 해 두었어요. 메일 등에 붙여넣어 보내 주세요.');
    } else {
      showMessage('기록을 저장하고 복사했어요. 메일 등에 붙여넣어 보내 주세요. (${f.path.split(RegExp(r'[\\/]')).last})');
    }
    return f;
  } catch (e, st) {
    log.error('[문제 신고] 기록 내보내기 실패', e, st);
    showMessage('기록을 내보내지 못했어요.');
    return null;
  }
}
