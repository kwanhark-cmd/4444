import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/errors.dart';
import '../../core/logger.dart';
import '../../data/database.dart';
import '../../services/ai/ai_provider.dart';
import '../../services/media_picker.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/report.dart';
import '../widgets/update_card.dart';
import 'onboarding_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final AppState s = context.read<AppState>();
  late final key = TextEditingController(text: s.user.apiKey);
  late final limit = TextEditingController(text: s.user.monthlyLimitUsd.toStringAsFixed(1));
  late final rate = TextEditingController(text: s.user.krwPerUsd.toStringAsFixed(0));
  late final sigungu = TextEditingController(text: s.user.sigungu);
  double month = 0;
  double total = 0;

  @override
  void initState() {
    super.initState();
    _costs();
  }

  Future<void> _costs() async {
    final m = await s.monthCost();
    final t = await s.totalCost();
    if (mounted) {
      setState(() {
        month = m;
        total = t;
      });
    }
  }

  String _krw(double usd) => '${(usd * s.user.krwPerUsd).round()}원 (\$${usd.toStringAsFixed(3)})';

  Future<void> _save() async {
    s.user.apiKey = key.text.trim();
    s.user.monthlyLimitUsd = double.tryParse(limit.text) ?? s.user.monthlyLimitUsd;
    s.user.krwPerUsd = double.tryParse(rate.text) ?? s.user.krwPerUsd;
    s.user.sigungu = sigungu.text.trim();
    await s.saveUser();
  }

  Widget _switch(String title, bool v, ValueChanged<bool> on, {String? sub}) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(title, style: const TextStyle(fontSize: 18)),
    subtitle: sub == null ? null : Text(sub, style: const TextStyle(fontSize: 15)),
    value: v,
    onChanged: (x) {
      on(x);
      setState(() {});
    },
  );

  Widget _choice<T>(List<(T, String)> options, T current, ValueChanged<T> on) {
    final p = context.palette;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (v, label) in options)
          BigButton(
            label: '${v == current ? '✓ ' : ''}$label',
            expand: false,
            color: v == current ? p.progress : p.muted,
            onTap: () {
              on(v);
              setState(() {});
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    context.watch<AppState>();
    final perPhoto = AiPricing.estimatePhotoUsd();
    return AppPage(
      title: '설정',
      body: ListView(
        key: const PageStorageKey('settings_1'),
        padding: const EdgeInsets.all(AppSizes.page),
        children: [
          // ---------- 맨 위: 업데이트 · 문제 신고 ----------
          const UpdateCard(),
          BigButton(label: '문제 신고 (기록 보내기)', emoji: 'warning', color: p.attention, textColor: p.onAttention, onTap: reportProblem),
          const SizedBox(height: AppSizes.cardGap),
          // ---------- 사용자 ----------
          const SectionTitle('사용자'),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('지금 사용자: ${s.currentUser?.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const Text('사용자마다 물건 목록이 따로 보관돼요.', style: TextStyle(fontSize: 15)),
                const SizedBox(height: 8),
                for (final u in s.users)
                  if (u.id != s.currentUser?.id)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: BigButton(label: '${u.name}(으)로 바꾸기', color: p.primary, onTap: () => s.switchUser(u.id)),
                          ),
                          IconButton(
                            tooltip: '사용자 지우기',
                            icon: Icon(Icons.delete_rounded, color: p.discard, size: 30),
                            onPressed: () async {
                              final ok = await confirmTwice(
                                context,
                                title: '사용자 지우기',
                                first: '"${u.name}"의 모든 물건과 설정을 지울까요?',
                                second: '되돌릴 수 없어요.',
                                okLabel: '지우기',
                              );
                              if (ok) await s.removeUser(u.id);
                            },
                          ),
                        ],
                      ),
                    ),
                BigButton(
                  label: '새 사용자 만들기',
                  icon: Icons.person_add_rounded,
                  color: p.muted,
                  onTap: () async {
                    final n = await askText(context, title: '이름', hint: '예: 엄마');
                    if (n != null) await s.addUser(n);
                  },
                ),
                const SizedBox(height: 8),
                BigButton(
                  label: '내 이름 바꾸기',
                  icon: Icons.edit_rounded,
                  color: p.muted,
                  onTap: () async {
                    final n = await askText(context, title: '이름', initial: s.currentUser?.name ?? '');
                    if (n == null || n.trim().isEmpty) return;
                    await s.repo.renameUser(s.uid, n.trim());
                    s.users = await s.repo.users();
                    await s.switchUser(s.uid);
                  },
                ),
              ],
            ),
          ),

          // ---------- 화면 ----------
          const SectionTitle('글씨와 화면'),
          _choice([for (final t in TextSizeChoice.values) (t, t.label)], s.global.textSize, (v) {
            s.global.textSize = v;
            s.saveGlobal();
          }),
          const SizedBox(height: 10),
          _choice([(ThemeModeChoice.light, '밝게'), (ThemeModeChoice.dark, '어둡게'), (ThemeModeChoice.highContrast, '고대비')], s.global.theme, (v) {
            s.global.theme = v;
            s.saveGlobal();
          }),
          _switch('움직임 줄이기', s.global.reduceMotion, (v) {
            s.global.reduceMotion = v;
            s.saveGlobal();
          }, sub: '화면 움직임 효과를 끕니다'),
          _switch('진동', s.global.haptics, (v) {
            s.global.haptics = v;
            s.saveGlobal();
          }),
          _switch('누를 때 소리', s.global.sound, (v) {
            s.global.sound = v;
            s.saveGlobal();
          }),

          // ---------- 지역 ----------
          const SectionTitle('사는 지역'),
          RegionFields(sido: s.user.sido, onSido: (v) => setState(() => s.user.sido = v), sigungu: sigungu),
          const SizedBox(height: 8),
          BigButton(
            label: '지역 저장',
            emoji: 'home',
            color: p.primary,
            onTap: () async {
              await _save();
              if (context.mounted) toast(context, '지역을 저장했어요: ${s.user.regionLabel}');
            },
          ),

          // ---------- AI ----------
          const SectionTitle('AI 연결'),
          Panel(
            border: s.user.aiConnected ? p.sell : p.attention,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(s.user.aiConnected ? '✓ Claude에 연결됨' : '연습 모드 (가짜 결과, 비용 0원)', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                _choice([('practice', '연습 모드'), ('claude', 'Claude')], s.user.aiProvider, (v) {
                  s.user.aiProvider = v;
                  _save();
                }),
                const SizedBox(height: 8),
                TextField(
                  controller: key,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'AI 연결 키 (API 키)'),
                  onSubmitted: (_) => _save(),
                ),
                const SizedBox(height: 4),
                Text('키는 이 기기 안에만 저장돼요. 백업 파일·기록에는 들어가지 않아요.', style: TextStyle(color: p.muted, fontSize: 15)),
                _switch('사진을 AI로 보내기', s.user.sendPhotosToAi, (v) {
                  s.user.sendPhotosToAi = v;
                  _save();
                }, sub: '켜야 실제 AI가 사진을 봐요. 끄면 사진은 기기 밖으로 나가지 않아요.'),
                const Divider(),
                Text('사진 한 장당 예상 비용: 약 ${_krw(perPhoto)}', style: const TextStyle(fontSize: 17)),
                Text('이번 달 사용: ${_krw(month)}', style: const TextStyle(fontSize: 17)),
                Text('지금까지 모두: ${_krw(total)}', style: const TextStyle(fontSize: 17)),
                const SizedBox(height: 8),
                TextField(
                  controller: limit,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: '월 한도 (달러)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: rate,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '환율 (1달러 = 몇 원)'),
                ),
                const SizedBox(height: 8),
                BigButton(
                  label: 'AI 설정 저장',
                  emoji: 'check',
                  color: p.primary,
                  onTap: () async {
                    await _save();
                    await _costs();
                    if (context.mounted) toast(context, s.user.aiConnected ? 'AI 연결을 저장했어요' : '연습 모드로 사용해요');
                  },
                ),
              ],
            ),
          ),

          // ---------- 음성 ----------
          const SectionTitle('음성'),
          _switch('읽어 주기', s.user.ttsOn, (v) {
            s.user.ttsOn = v;
            s.saveUser();
          }, sub: s.voice.canSpeak ? null : '이 기기에서는 읽어 주기를 지원하지 않아요'),
          Text('읽는 속도', style: Theme.of(context).textTheme.titleMedium),
          Slider(
            value: s.user.ttsRate.clamp(0.2, 0.8),
            min: 0.2,
            max: 0.8,
            divisions: 6,
            label: s.user.ttsRate < 0.4 ? '느리게' : (s.user.ttsRate > 0.55 ? '빠르게' : '보통'),
            onChanged: (v) => setState(() => s.user.ttsRate = v),
            onChangeEnd: (_) => s.saveUser(),
          ),
          BigButton(label: '읽기 시험', emoji: 'speaker', color: p.progress, onTap: () => s.say('안녕하세요. 이 속도로 읽어 드릴게요.')),
          _switch('말로 입력하기', s.user.voiceInputOn, (v) {
            s.user.voiceInputOn = v;
            s.saveUser();
          }, sub: s.voice.canListen ? '기기 내장 음성 인식을 사용해요' : '이 기기에서는 마이크 대신 글자 입력칸이 나와요'),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('외부 음성 서비스 사용', style: TextStyle(fontSize: 18)),
            subtitle: Text('준비 중 · 지금은 기기 내장 음성을 사용해요'),
          ),

          // ---------- 알림 ----------
          const SectionTitle('하루 한 번 비우기 알림'),
          _switch('매일 알림 받기', s.user.dailyOn, (v) {
            s.user.dailyOn = v;
            s.saveUser();
          }, sub: '알림이 안 와도 앱을 열면 밀린 알림을 보여 드려요'),
          Text('알림 시각: 매일 ${s.user.dailyHour}시', style: const TextStyle(fontSize: 18)),
          Slider(
            value: s.user.dailyHour.toDouble(),
            min: 5,
            max: 22,
            divisions: 17,
            label: '${s.user.dailyHour}시',
            onChanged: (v) => setState(() => s.user.dailyHour = v.round()),
            onChangeEnd: (_) => s.saveUser(),
          ),

          // ---------- 판매 ----------
          const SectionTitle('판매 규칙'),
          Text('안 팔리면 ${s.user.priceDropDays}일마다 ${s.user.priceDropPercent}% 인하를 추천해요', style: const TextStyle(fontSize: 17)),
          Slider(
            value: s.user.priceDropDays.toDouble(),
            min: 7,
            max: 60,
            divisions: 53,
            label: '${s.user.priceDropDays}일',
            onChanged: (v) => setState(() => s.user.priceDropDays = v.round()),
            onChangeEnd: (_) => s.saveUser(),
          ),
          Slider(
            value: s.user.priceDropPercent.toDouble(),
            min: 5,
            max: 30,
            divisions: 5,
            label: '${s.user.priceDropPercent}%',
            onChanged: (v) => setState(() => s.user.priceDropPercent = v.round()),
            onChangeEnd: (_) => s.saveUser(),
          ),
          const Text('1년 동안 안 팔린 물건은 7일 전에 알려 드리고 폐기 목록으로 옮겨요.', style: TextStyle(fontSize: 16)),

          // ---------- 사진 ----------
          const SectionTitle('사진'),
          _switch('원본 사진도 보관', s.user.keepOriginals, (v) {
            s.user.keepOriginals = v;
            s.saveUser();
          }, sub: '끄면 줄인 사진만 저장해 공간을 아껴요'),

          // ---------- 연결 ----------
          const SectionTitle('다른 앱 연결'),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Emoji3D('speech', size: 36),
            title: Text('제미나이 정리 글', style: TextStyle(fontSize: 18)),
            subtitle: Text('공유하기 또는 붙여넣기로 가져올 수 있어요 (물건 등록 화면)'),
          ),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Emoji3D('bell', size: 36),
            title: Text('지메일 자동 읽기', style: TextStyle(fontSize: 18)),
            subtitle: Text('준비 중 · 지금은 붙여넣기를 사용해 주세요'),
          ),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Emoji3D('gear', size: 36),
            title: Text('아이폰 지원', style: TextStyle(fontSize: 18)),
            subtitle: Text('준비 중'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Emoji3D('folder', size: 36),
            title: const Text('내보내기 폴더', style: TextStyle(fontSize: 18)),
            subtitle: Text(s.paths.exports.path, style: const TextStyle(fontSize: 14)),
            onTap: () {
              Clipboard.setData(ClipboardData(text: s.paths.exports.path));
              toast(context, '폴더 위치를 복사했어요');
            },
          ),

          // ---------- 데이터 ----------
          const SectionTitle('백업과 복원'),
          BigButton(label: '백업 파일 만들기', emoji: 'package', color: p.primary, onTap: _backup),
          const SizedBox(height: 8),
          BigButton(label: '백업에서 되살리기', emoji: 'folder', color: p.primary, onTap: _restore),
          const SizedBox(height: 8),
          BigButton(label: '문제 신고 (기록 내보내기)', emoji: 'warning', color: p.attention, textColor: p.onAttention, onTap: _report),
          const SizedBox(height: AppSizes.gapLarge),
          BigButton(label: '모두 지우고 처음부터', icon: Icons.restart_alt_rounded, color: p.discard, onTap: _reset),

          // ---------- 정보 ----------
          const SectionTitle('앱 정보'),
          Text('버전 $appVersion · 데이터 버전 $dataVersion', style: const TextStyle(fontSize: 17)),
          const SizedBox(height: 8),
          BigButton(label: '사용한 그림·글꼴 라이선스', icon: Icons.info_outline_rounded, color: p.muted, onTap: _licenses),
          const SizedBox(height: 8),
          BigButton(
            label: '처음 설정 다시 하기',
            icon: Icons.replay_rounded,
            color: p.muted,
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OnboardingAgain()));
            },
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Future<void> _backup() async {
    final pw = await askText(context, title: '백업 비밀번호', hint: '4글자 이상 · 꼭 기억해 두세요');
    if (pw == null || !mounted) return;
    final picker = context.read<MediaPicker>();
    try {
      final f = await s.backup.createFile(pw, appVersion: appVersion);
      final dir = await picker.chooseSaveFolder();
      var where = f.path;
      if (dir != null) {
        final out = await f.copy('$dir${Platform.pathSeparator}${f.uri.pathSegments.last}');
        where = out.path;
      }
      if (mounted) {
        Clipboard.setData(ClipboardData(text: where));
        toast(context, '백업을 만들었어요 (위치 복사됨): $where');
      }
    } on UserFacingException catch (e) {
      if (mounted) toast(context, e.message);
    } catch (e, st) {
      log.error('백업 실패', e, st);
      if (mounted) toast(context, '백업을 만들지 못했어요. 저장 공간을 확인해 주세요.');
    }
  }

  Future<void> _restore() async {
    final path = await context.read<MediaPicker>().pickBackupFile();
    if (path == null || !mounted) return;
    final ok = await confirmTwice(context, title: '백업에서 되살리기', first: '지금 기기의 물건 목록이 백업 내용으로 바뀌어요.', second: '지금 자료는 사라져요. 계속할까요?', okLabel: '되살리기');
    if (!ok || !mounted) return;
    final pw = await askText(context, title: '백업 비밀번호');
    if (pw == null) return;
    try {
      await s.backup.restoreBytes(await File(path).readAsBytes(), pw);
      await s.reloadAfterRestore();
      if (mounted) toast(context, '백업에서 되살렸어요');
    } on UserFacingException catch (e) {
      if (mounted) toast(context, e.message);
    } catch (e, st) {
      log.error('복원 실패', e, st);
      if (mounted) toast(context, '되살리지 못했어요. 파일이 맞는지 확인해 주세요.');
    }
  }

  Future<void> _report() async {
    final text = await log.exportText(appVersion: appVersion, platform: '${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
    final f = await s.exports.exportReport(text, DateTime.now());
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) toast(context, '기록을 저장하고 복사했어요. 이메일 등에 붙여넣어 보내 주세요. (${f.path.split(RegExp(r'[\\/]')).last})');
  }

  Future<void> _reset() async {
    final ok = await confirmTwice(
      context,
      title: '모두 지우기',
      first: '모든 사용자·물건·사진·설정을 지워요.',
      second: '정말 모두 지울까요? 되돌릴 수 없어요. (백업을 먼저 만들어 두세요)',
      okLabel: '모두 지우기',
    );
    if (!ok) return;
    await s.resetAll();
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _licenses() async {
    final fluent = await rootBundle.loadString('assets/licenses/FluentEmoji-MIT.txt');
    final noto = await rootBundle.loadString('assets/licenses/NotoSansKR-OFL.txt');
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('라이선스'),
        content: SingleChildScrollView(
          child: Text(
            '3D 아이콘: Microsoft Fluent Emoji (MIT)\n\n$fluent\n\n글꼴: Noto Sans KR (SIL OFL 1.1)\n\n$noto\n\n마스코트: 이 앱 전용 그림',
            style: const TextStyle(fontSize: 13),
          ),
        ),
        actions: [BigButton(label: '닫기', expand: false, onTap: () => Navigator.pop(ctx))],
      ),
    );
  }
}

/// 설정에서 마법사를 다시 열 때
class OnboardingAgain extends StatelessWidget {
  const OnboardingAgain({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    s.global.onboarded = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      s.saveGlobal();
      Navigator.of(context).popUntil((r) => r.isFirst);
    });
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
