import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/errors.dart';
import '../../core/logger.dart';
import '../../core/platform.dart';
import '../../services/update_service.dart';
import '../../services/video_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import 'backup_actions.dart';
import 'common.dart';

/// 새 버전을 받는 공개 화면 (GitHub 로그인 없이 열려요)
const releasesPage = 'https://github.com/${UpdateService.repo}/releases/latest';

/// 안드로이드 새 버전 설치 순서. 예전 앱을 지우면 앱 안 자료도 지워지므로 백업(앱 밖에 저장)이 맨 먼저.
const androidUpdateSteps = [
  '백업 파일 만들기 → 저장 화면에서 다운로드 폴더나 구글 드라이브에 저장 (앱 밖에 저장해야 앱을 지워도 남아요)',
  '새 설치 파일(binugi-android.apk) 내려받기',
  '백업 파일이 다운로드 폴더나 드라이브에 있는지 확인한 뒤에 예전 앱 지우기',
  '내려받은 새 파일을 눌러 설치',
  '새 앱 첫 화면에서 "백업에서 되살리기" → 백업 비밀번호 넣기 (AI 열쇠·지메일은 다시 연결)',
];

/// 브라우저로 주소 열기. 테스트에서는 가짜로 바꿔 끼웁니다.
Future<bool> Function(Uri) openInBrowser = (u) => launchUrl(u, mode: LaunchMode.externalApplication);

/// 설정 맨 위: 지금 버전 + "업데이트 확인"
class UpdateCard extends StatefulWidget {
  const UpdateCard({super.key});
  @override
  State<UpdateCard> createState() => _UpdateCardState();
}

class _UpdateCardState extends State<UpdateCard> {
  bool checking = false;

  Future<void> _check() async {
    final s = context.read<AppState>();
    setState(() => checking = true);
    try {
      final info = await s.checkUpdateNow();
      if (!mounted) return;
      if (info == null) {
        toast(context, '지금이 최신 버전이에요 ($appVersion)');
      } else {
        await showUpdateDialog(context, info);
      }
    } catch (e, st) {
      if (mounted) setState(() => checking = false);
      await showFailure(null, stage: '업데이트', message: '업데이트를 확인하지 못했어요. 인터넷 연결을 확인해 주세요.', error: e, stack: st, onRetry: _check);
    } finally {
      if (mounted) setState(() => checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final p = context.palette;
    return Panel(
      fill: s.hasUpdate ? p.attention.withValues(alpha: 0.35) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Emoji3D('package', size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('앱 버전 $appVersion', style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      s.hasUpdate
                          ? '새 버전 ${s.global.latestVersion}이(가) 나왔어요'
                          : (isAndroidDevice ? '새 버전은 백업 → 예전 앱 지우기 → 새로 설치 순서로 바꿔요' : '물건·사진·설정은 업데이트해도 그대로 남아요'),
                      style: const TextStyle(fontSize: 15),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          BigButton(
            label: checking ? '확인하는 중…' : (s.hasUpdate ? (isAndroidDevice ? '새 버전 설치 순서 보기' : '새 버전 설치하기') : '업데이트 확인'),
            emoji: 'sparkle',
            color: s.hasUpdate ? p.sell : p.primary,
            onTap: checking ? null : (s.hasUpdate && s.update != null ? () => showUpdateDialog(context, s.update!) : _check),
          ),
        ],
      ),
    );
  }
}

/// 새 버전 안내. 안드로이드는 순서 안내(백업 먼저)와 내려받기 화면 열기만, 컴퓨터는 자동 백업 후 내려받아 설치.
Future<void> showUpdateDialog(BuildContext context, UpdateInfo info) async {
  if (isAndroidDevice) return showAndroidUpdateDialog(context, info);
  final ok = await confirmOnce(
    context,
    title: '새 버전 ${info.version}',
    message: '${info.notes.isEmpty ? '새 버전이 나왔어요.' : info.notes}\n\n설치해도 물건·사진·설정은 그대로 남아요. 설치 전에 자동으로 백업해 둘게요.',
    okLabel: '내려받아 설치',
  );
  if (!ok || !context.mounted) return;
  if (info.assetUrl == null) {
    toast(context, '이 기기용 설치 파일이 아직 없어요. 잠시 뒤 다시 확인해 주세요.');
    return;
  }
  final s = context.read<AppState>();
  final progress = ValueNotifier<double>(0);
  final cancel = CancelToken();
  final nav = Navigator.of(context, rootNavigator: true);
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('새 버전 내려받는 중'),
        content: ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (_, v, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BigProgress(v, label: '내려받기'),
              const SizedBox(height: 8),
              Text('${(v * 100).round()}%', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        actions: [BigButton(label: '취소', expand: false, color: ctx.palette.discard, onTap: cancel.cancel)],
      ),
    ),
  );
  try {
    await s.backup.createSafetyBackup('업데이트설치', appVersion: appVersion);
    final file = await s.updates.download(info, onProgress: (v) => progress.value = v, cancel: cancel);
    if (nav.mounted) nav.pop();
    final quit = await s.updates.install(file);
    if (quit) {
      log.info('업데이트 설치를 위해 앱을 닫습니다');
      await Future<void>.delayed(const Duration(milliseconds: 500));
      exit(0);
    }
  } on UserFacingException catch (e) {
    if (nav.mounted) nav.pop();
    await showFailure(null, stage: '업데이트', message: e.message);
  } catch (e, st) {
    if (nav.mounted) nav.pop();
    await showFailure(null, stage: '업데이트', message: '업데이트를 설치하지 못했어요. 다시 해 보거나 문제 신고로 기록을 보내 주세요.', error: e, stack: st);
  }
}

/// 안드로이드: 앱 안에서 설치하지 않아요 (예전 앱 위에 덮어 설치가 안 되므로).
/// 순서 안내 + "백업 파일 만들기" + "내려받기 화면 열기"(브라우저).
Future<void> showAndroidUpdateDialog(BuildContext context, UpdateInfo info) async {
  var backedUp = false;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) {
        final p = ctx.palette;
        return AlertDialog(
          title: Text('새 버전 ${info.version}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('안드로이드는 예전 앱 위에 덮어 설치할 수 없어요. 예전 앱을 지우면 앱 안의 물건·사진·설정도 함께 지워지니, 꼭 이 순서대로 해 주세요.', style: TextStyle(fontSize: 18)),
                const SizedBox(height: 12),
                const StepList(androidUpdateSteps),
                if (info.notes.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('이번 버전 안내', style: Theme.of(ctx).textTheme.titleMedium),
                  Text(info.notes.trim(), style: const TextStyle(fontSize: 16)),
                ],
              ],
            ),
          ),
          actionsOverflowDirection: VerticalDirection.up,
          actions: [
            BigButton(label: '닫기', color: p.muted, expand: false, onTap: () => Navigator.pop(ctx)),
            BigButton(
              label: '2. 내려받기 화면 열기',
              color: p.primary,
              expand: false,
              onTap: () async {
                if (!backedUp) {
                  final go = await confirmOnce(
                    ctx,
                    title: '백업 파일은 만들었나요?',
                    message: '예전 앱을 지우기 전에 꼭 "백업 파일 만들기"로 백업 파일을 앱 밖(다운로드 폴더·드라이브)에 저장해 주세요. 백업 없이 앱을 지우면 자료가 모두 사라져요.',
                    okLabel: '내려받기 화면 열기',
                  );
                  if (!go) return;
                }
                await openDownloadPage(info);
              },
            ),
            BigButton(
              label: backedUp ? '✓ 백업 파일 저장함' : '1. 백업 파일 만들기',
              color: backedUp ? p.progress : p.sell,
              expand: false,
              onTap: () async {
                final ok = await makeBackupFile(ctx);
                if (ok && ctx.mounted) setD(() => backedUp = true);
              },
            ),
          ],
        );
      },
    ),
  );
}

/// 새 설치 파일(또는 공개 내려받기 화면)을 브라우저로 엽니다. 못 열면 주소를 복사해 알려 줘요.
Future<void> openDownloadPage(UpdateInfo info) async {
  final url = info.assetUrl ?? releasesPage;
  var opened = false;
  try {
    opened = await openInBrowser(Uri.parse(url));
  } catch (e) {
    log.error('[업데이트] 내려받기 화면 열기 실패', e);
  }
  if (!opened) {
    await Clipboard.setData(ClipboardData(text: releasesPage));
    showMessage('브라우저를 열지 못했어요. 주소를 복사했어요: $releasesPage');
  }
}
