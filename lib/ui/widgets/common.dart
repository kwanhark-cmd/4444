import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../state/app_state.dart';
import '../../core/logger.dart';
import '../../theme/app_theme.dart';
import '../keys.dart';
import 'report.dart';

/// 3D 이모지 그림 (assets/emoji/이름.png)
class Emoji3D extends StatelessWidget {
  final String name;
  final double size;
  const Emoji3D(this.name, {super.key, this.size = AppSizes.tileIcon});
  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/emoji/$name.png',
    width: size,
    height: size,
    cacheWidth: (size * 2).round(),
    errorBuilder: (_, _, _) => SizedBox(width: size, height: size),
    excludeFromSemantics: true,
  );
}

enum MascotMood { hello, thinking, recommend, caution, celebrate }

/// 앱 마스코트 (assets/mascot/*.svg 파일만 바꾸면 교체됨)
class Mascot extends StatelessWidget {
  final MascotMood mood;
  final double size;
  const Mascot(this.mood, {super.key, this.size = 96});
  @override
  Widget build(BuildContext context) => SvgPicture.asset('assets/mascot/${mood.name}.svg', width: size, height: size, excludeFromSemantics: true);
}

/// 누르면 눌리고 튀어오르는 효과 + 진동·소리 피드백
class Pressable extends StatefulWidget {
  final Widget Function(BuildContext context, bool pressed) builder;
  final VoidCallback? onTap;
  final String? semanticLabel;
  const Pressable({super.key, required this.builder, this.onTap, this.semanticLabel});
  @override
  State<Pressable> createState() => _PressableState();
}

void feedback(BuildContext context) {
  final s = context.read<AppState>().global;
  if (s.haptics) HapticFeedback.lightImpact();
  if (s.sound) SystemSound.play(SystemSoundType.click);
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final m = context.motion;
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        onTapDown: widget.onTap == null ? null : (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap == null
            ? null
            : () {
                feedback(context);
                widget.onTap!();
              },
        child: AnimatedScale(scale: _down ? 0.96 : 1, duration: m.fast, curve: Curves.easeOutBack, child: widget.builder(context, _down)),
      ),
    );
  }
}

/// 메인 화면 큰 카드형 타일 (3D 아이콘 + 이름 + 한 줄 설명)
class Tile3D extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final String? badge;
  const Tile3D({super.key, required this.emoji, required this.title, required this.subtitle, required this.color, required this.onTap, this.badge});
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Pressable(
      semanticLabel: '$title. $subtitle',
      onTap: onTap,
      builder: (context, pressed) => AnimatedContainer(
        duration: context.motion.fast,
        // 바깥 색 층 = 두께(3D). 누르면 두께가 줄어 눌린 느낌.
        margin: EdgeInsets.only(top: pressed ? AppSizes.depth - 1 : 0),
        padding: EdgeInsets.only(bottom: pressed ? 1 : AppSizes.depth),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppSizes.radius),
          boxShadow: AppShadows.raised(p, pressed: pressed),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(AppSizes.radius),
            border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
          ),
          padding: const EdgeInsets.all(AppSizes.gap),
          child: Row(
            children: [
              Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.002)
                  ..rotateX(pressed ? 0 : -0.15)
                  ..rotateY(pressed ? 0 : 0.15),
                child: Emoji3D(emoji),
              ),
              const SizedBox(width: AppSizes.gap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: p.muted)),
                  ],
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: p.attention, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    badge!,
                    style: TextStyle(color: p.onAttention, fontWeight: FontWeight.w700),
                  ),
                ),
              Icon(Icons.chevron_right, color: p.muted, size: 32),
            ],
          ),
        ),
      ),
    );
  }
}

/// 색이 있는 큰 버튼 (입체감 + 눌림)
class BigButton extends StatelessWidget {
  final String label;
  final String? emoji;
  final IconData? icon;
  final Color? color;
  final Color? textColor;
  final VoidCallback? onTap;
  final bool expand;
  const BigButton({super.key, required this.label, this.emoji, this.icon, this.color, this.textColor, this.onTap, this.expand = true});
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bg = onTap == null ? p.border : (color ?? p.primary);
    final fg = onTap == null ? p.muted : (textColor ?? (color == null ? p.onPrimary : Colors.white));
    final child = Pressable(
      semanticLabel: label,
      onTap: onTap,
      builder: (context, pressed) => AnimatedContainer(
        duration: context.motion.fast,
        constraints: const BoxConstraints(minHeight: AppSizes.buttonMinHeight, minWidth: AppSizes.touchMin),
        margin: EdgeInsets.only(top: pressed ? 3 : 0),
        padding: EdgeInsets.only(bottom: pressed ? 1 : 4),
        decoration: BoxDecoration(
          color: Color.lerp(bg, Colors.black, 0.35),
          borderRadius: BorderRadius.circular(AppSizes.radius),
          boxShadow: onTap == null ? null : AppShadows.raised(p, pressed: pressed),
        ),
        child: Container(
          constraints: BoxConstraints(minHeight: AppSizes.buttonMinHeight - (pressed ? 1 : 4)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppSizes.radius)),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (emoji != null) ...[Emoji3D(emoji!, size: 32), const SizedBox(width: 10)],
              if (icon != null) ...[Icon(icon, color: fg, size: 28), const SizedBox(width: 10)],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: fg, fontSize: 18, fontWeight: FontWeight.w700, fontFamily: appFont),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: child) : child;
  }
}

Color decisionColor(BuildContext context, Decision? d) {
  final p = context.palette;
  return switch (d) {
    Decision.use => p.use,
    Decision.sell => p.sell,
    Decision.discard => p.discard,
    null => p.attention,
  };
}

/// 분류 버튼 (색 + 아이콘 + 글자)
class DecisionButton extends StatelessWidget {
  final Decision decision;
  final VoidCallback onTap;
  final bool compact;
  const DecisionButton(this.decision, {super.key, required this.onTap, this.compact = false});
  @override
  Widget build(BuildContext context) => BigButton(label: decision.label, emoji: decision.emoji, color: decisionColor(context, decision), onTap: onTap);
}

/// 분류 세 버튼 (작은 화면에서는 세로로)
class DecisionButtons extends StatelessWidget {
  final void Function(Decision) onPick;
  const DecisionButtons({super.key, required this.onPick});
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final row = c.maxWidth > 560 && scale < 1.3;
        final buttons = [
          for (final d in [Decision.use, Decision.sell, Decision.discard]) DecisionButton(d, onTap: () => onPick(d)),
        ];
        if (row) {
          return Row(
            children: [
              for (final b in buttons)
                Expanded(
                  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: b),
                ),
            ],
          );
        }
        return Column(
          children: [
            for (final b in buttons)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.gapSmall),
                child: b,
              ),
          ],
        );
      },
    );
  }
}

/// 상태 딱지 (판매중·예약·판매완료·미정 등)
class Chip3 extends StatelessWidget {
  final String text;
  final Color color;
  final Color? textColor;
  const Chip3(this.text, this.color, {super.key, this.textColor});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
    child: Text(
      text,
      style: TextStyle(color: textColor ?? Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
    ),
  );
}

Widget decisionChip(BuildContext context, Decision? d) {
  final p = context.palette;
  if (d == null) return Chip3('아직 안 정함', p.attention, textColor: p.onAttention);
  return Chip3(d.label, decisionColor(context, d));
}

/// 물건 사진 (작게 캐시)
class ItemPhoto extends StatelessWidget {
  final Item item;
  final double? height;
  final bool full;
  const ItemPhoto(this.item, {super.key, this.height, this.full = false});
  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final rel = full ? (item.photoPath ?? item.thumbPath) : (item.thumbPath ?? item.photoPath);
    final p = context.palette;
    Widget placeholder() => Container(height: height, color: p.background, alignment: Alignment.center, child: const Emoji3D('package', size: 48));
    if (rel == null) return placeholder();
    final f = File(state.paths.abs(rel));
    return Image.file(f, height: height, width: double.infinity, fit: BoxFit.cover, cacheWidth: full ? 1000 : 400, errorBuilder: (_, _, _) => placeholder());
  }
}

/// 물건 목록 카드: 사진 중심, 테두리 색이 분류. (가벼운 평면 카드)
class ItemCard extends StatelessWidget {
  final Item item;
  final VoidCallback onTap;
  final Widget? trailing;
  const ItemCard(this.item, {super.key, required this.onTap, this.trailing});
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = decisionColor(context, item.decision);
    return Semantics(
      button: true,
      label: '${item.name}, ${item.decision?.label ?? '아직 안 정함'}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radius),
        child: Container(
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(AppSizes.radius),
            border: Border.all(color: color, width: AppSizes.cardBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 104, height: 104, child: ItemPhoto(item, height: 104)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, style: Theme.of(context).textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          decisionChip(context, item.decision),
                          if (item.saleStatus != null) Chip3(item.saleStatus!.label, p.progress),
                          if (item.discardDoneAt != null) Chip3('폐기 완료', p.muted),
                        ],
                      ),
                      if (item.room.isNotEmpty || item.spot.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          [item.room, item.spot].where((s) => s.isNotEmpty).join(' · '),
                          style: TextStyle(color: p.muted, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// 큰 진행 막대
class BigProgress extends StatelessWidget {
  final double value;
  final Color? color;
  final String? label;
  const BigProgress(this.value, {super.key, this.color, this.label});
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      label: label,
      value: '${(value * 100).round()}%',
      child: Container(
        height: 22,
        decoration: BoxDecoration(color: p.border, borderRadius: BorderRadius.circular(11)),
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.centerLeft,
        child: AnimatedFractionallySizedBox(
          duration: context.motion.slow,
          widthFactor: value.clamp(0, 1),
          child: Container(color: color ?? p.progress),
        ),
      ),
    );
  }
}

/// 빈 화면 안내 + 큰 버튼
class EmptyState extends StatelessWidget {
  final String message;
  final String? buttonLabel;
  final VoidCallback? onButton;
  final MascotMood mood;
  const EmptyState({super.key, required this.message, this.buttonLabel, this.onButton, this.mood = MascotMood.hello});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSizes.gapLarge),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Mascot(mood, size: 120),
        const SizedBox(height: AppSizes.gap),
        Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
        if (buttonLabel != null) ...[const SizedBox(height: AppSizes.gap), BigButton(label: buttonLabel!, emoji: 'camera', onTap: onButton)],
      ],
    ),
  );
}

/// 공통 화면 틀: 같은 자리의 "뒤로"·"홈" 버튼, 큰 제목
class AppPage extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? bottom;
  final bool showHome;
  const AppPage({super.key, required this.title, required this.body, this.actions, this.bottom, this.showHome = true});
  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: canPop
            ? IconButton(tooltip: '뒤로', icon: const Icon(Icons.arrow_back_rounded, size: 30), onPressed: () => Navigator.of(context).maybePop())
            : null,
        title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
        actions: [
          ...?actions,
          if (showHome && canPop)
            IconButton(tooltip: '홈', icon: const Icon(Icons.home_rounded, size: 30), onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst)),
        ],
      ),
      body: SafeArea(child: body),
      bottomNavigationBar: bottom == null
          ? null
          : SafeArea(
              child: Padding(padding: const EdgeInsets.all(AppSizes.page), child: bottom),
            ),
    );
  }
}

/// 위험한 동작은 2단계 확인
Future<bool> confirmTwice(BuildContext context, {required String title, required String first, required String second, String okLabel = '네, 할게요'}) async {
  final a = await confirmOnce(context, title: title, message: first, okLabel: '다음', danger: true);
  final c = liveContext();
  if (!a || c == null) return false;
  // liveContext()가 살아 있는(mounted) 화면만 돌려주므로 안전
  // ignore: use_build_context_synchronously
  return confirmOnce(c, title: '정말 할까요?', message: second, okLabel: okLabel, danger: true);
}

Future<bool> confirmOnce(BuildContext context, {required String title, required String message, String okLabel = '확인', bool danger = false}) async {
  final c = liveContext(context);
  if (c == null) return false;
  final p = c.palette;
  final r = await showDialog<bool>(
    context: c,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(child: Text(message, style: const TextStyle(fontSize: 18))),
      actionsOverflowDirection: VerticalDirection.up,
      actions: [
        BigButton(label: '아니요', color: p.muted, expand: false, onTap: () => Navigator.pop(ctx, false)),
        BigButton(
          label: okLabel,
          color: danger ? p.discard : p.primary,
          textColor: danger ? Colors.white : p.onPrimary,
          expand: false,
          onTap: () => Navigator.pop(ctx, true),
        ),
      ],
    ),
  );
  return r ?? false;
}

void toast(BuildContext context, String msg, {String? actionLabel, VoidCallback? onAction}) => showMessage(msg, actionLabel: actionLabel, onAction: onAction);

/// 화면 아래 알림줄. context 없이 앱 전체 알림줄을 써서 화면이 사라져도 안전.
void showMessage(String msg, {String? actionLabel, VoidCallback? onAction}) {
  final m = messengerKey.currentState;
  if (m == null) return;
  m.hideCurrentSnackBar();
  m.showSnackBar(
    SnackBar(
      content: Text(msg),
      duration: const Duration(seconds: 5),
      action: actionLabel == null ? null : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
    ),
  );
}

/// 실패 안내 창: 원인과 단계를 기록하고 "다시 시도"·"문제 신고"·"닫기"를 보여 줍니다.
/// [stage]: 카메라 / 파일 / AI 인식 / 저장 / 지메일 / 업데이트 등
Future<void> showFailure(
  BuildContext? context, {
  required String stage,
  required String message,
  Object? error,
  StackTrace? stack,
  Future<void> Function()? onRetry,
  String? altLabel,
  Future<void> Function()? onAlt,
}) async {
  log.error('[$stage] $message', error, stack);
  final c = liveContext(context);
  if (c == null) return;
  final p = c.palette;
  final choice = await showDialog<String>(
    context: c,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          const Emoji3D('warning', size: 36),
          const SizedBox(width: 8),
          Expanded(child: Text('$stage 문제')),
        ],
      ),
      content: SingleChildScrollView(child: Text(message, style: const TextStyle(fontSize: 18))),
      actionsOverflowDirection: VerticalDirection.down,
      actionsOverflowButtonSpacing: 8,
      actions: [
        if (onRetry != null) BigButton(label: '다시 시도', emoji: 'sparkle', color: p.primary, onTap: () => Navigator.pop(ctx, 'retry')),
        if (onAlt != null) BigButton(label: altLabel ?? '다른 방법', color: p.progress, onTap: () => Navigator.pop(ctx, 'alt')),
        BigButton(label: '문제 신고', emoji: 'warning', color: p.attention, textColor: p.onAttention, onTap: () => Navigator.pop(ctx, 'report')),
        BigButton(label: '닫기', color: p.muted, onTap: () => Navigator.pop(ctx, 'close')),
      ],
    ),
  );
  // 창이 닫힌 뒤에는 처음 context가 사라졌을 수 있으므로 다음 동작은 context 없이 실행
  switch (choice) {
    case 'retry':
      await onRetry?.call();
    case 'alt':
      await onAlt?.call();
    case 'report':
      await reportProblem();
  }
}

/// 글자 입력 대화상자 (마이크가 없을 때 대신)
Future<String?> askText(BuildContext context, {required String title, String hint = '', String initial = '', int lines = 1}) async {
  final live = liveContext(context);
  if (live == null) return null;
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: live,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        minLines: lines,
        maxLines: lines < 2 ? 1 : 8,
        decoration: InputDecoration(hintText: hint),
        style: const TextStyle(fontSize: 18),
      ),
      actionsOverflowDirection: VerticalDirection.up,
      actions: [
        BigButton(label: '취소', color: Theme.of(ctx).extension<AppThemeExt>()!.palette.muted, expand: false, onTap: () => Navigator.pop(ctx)),
        BigButton(label: '확인', expand: false, onTap: () => Navigator.pop(ctx, c.text)),
      ],
    ),
  );
}

/// 음성으로 말하기 버튼. 마이크가 안 되면 글자 입력칸을 보여 줍니다.
Future<String?> listenOrType(BuildContext context, {required String title, String hint = '', String initial = '', int lines = 2}) async {
  final state = context.read<AppState>();
  if (state.user.voiceInputOn && state.voice.canListen) {
    final said = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ListeningDialog(title: title),
    );
    if (said != null && said.trim().isNotEmpty) return said;
    if (!context.mounted) return null;
  }
  if (!context.mounted) return null;
  return askText(context, title: title, hint: hint, initial: initial, lines: lines);
}

class _ListeningDialog extends StatefulWidget {
  final String title;
  const _ListeningDialog({required this.title});
  @override
  State<_ListeningDialog> createState() => _ListeningDialogState();
}

class _ListeningDialogState extends State<_ListeningDialog> {
  @override
  void initState() {
    super.initState();
    final voice = context.read<AppState>().voice;
    voice.listenOnce().then((t) {
      if (mounted) Navigator.pop(context, t);
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Emoji3D('mic', size: 80),
        const SizedBox(height: 12),
        const Text('듣고 있어요… 말씀해 주세요', style: TextStyle(fontSize: 18)),
        const SizedBox(height: 12),
        LinearProgressIndicator(color: context.palette.progress),
      ],
    ),
    actions: [
      BigButton(
        label: '글로 쓸게요',
        expand: false,
        onTap: () {
          context.read<AppState>().voice.stopListening();
          Navigator.pop(context, null);
        },
      ),
    ],
  );
}

/// 화면 아래 가운데 크고 둥근 촬영·녹음 버튼
class CaptureButton extends StatelessWidget {
  final String emoji;
  final String label;
  final VoidCallback onTap;
  const CaptureButton({super.key, required this.emoji, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Pressable(
          semanticLabel: label,
          onTap: onTap,
          builder: (context, pressed) => AnimatedContainer(
            duration: context.motion.fast,
            width: AppSizes.captureButton,
            height: AppSizes.captureButton,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: p.accent,
              border: Border.all(color: p.surface, width: 4),
              boxShadow: AppShadows.raised(p, pressed: pressed),
            ),
            alignment: Alignment.center,
            child: Emoji3D(emoji, size: 48),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(20)),
          child: Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: p.onAccent),
          ),
        ),
      ],
    );
  }
}

/// 첫 사용 말풍선 안내 (한 번만)
class FirstTimeTip extends StatefulWidget {
  final String id;
  final String text;
  const FirstTimeTip({super.key, required this.id, required this.text});
  @override
  State<FirstTimeTip> createState() => _FirstTimeTipState();
}

class _FirstTimeTipState extends State<FirstTimeTip> {
  bool? _show;
  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();
    s.repo.getSetting(s.uid, 'tip_${widget.id}').then((v) {
      if (mounted) setState(() => _show = v != '1');
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_show != true) return const SizedBox.shrink();
    final p = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.gap),
      padding: const EdgeInsets.all(AppSizes.gap),
      decoration: BoxDecoration(color: p.attention, borderRadius: BorderRadius.circular(AppSizes.radius)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Emoji3D('idea', size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Text(widget.text, style: TextStyle(color: p.onAttention, fontSize: 17)),
          ),
          IconButton(
            tooltip: '닫기',
            icon: Icon(Icons.close, color: p.onAttention),
            onPressed: () {
              final s = context.read<AppState>();
              s.repo.setSetting(s.uid, 'tip_${widget.id}', '1');
              setState(() => _show = false);
            },
          ),
        ],
      ),
    );
  }
}

/// 섹션 제목
class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSizes.gapLarge, bottom: AppSizes.gapSmall),
    child: Text(text, style: Theme.of(context).textTheme.titleLarge),
  );
}

/// 카드 상자
class Panel extends StatelessWidget {
  final Widget child;
  final Color? border; // 강조색: 왼쪽 색 띠로 표시
  final Color? fill; // 배경색 (기본: 카드색)
  const Panel({super.key, required this.child, this.border, this.fill});
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final hc = Theme.of(context).extension<AppThemeExt>()!.highContrast;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.cardGap),
      child: Material(
        color: fill ?? p.surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radius),
          side: hc ? BorderSide(color: p.border, width: 2) : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: DecoratedBox(
          decoration: BoxDecoration(boxShadow: AppShadows.soft(p)),
          child: Stack(
            children: [
              Padding(padding: EdgeInsets.fromLTRB(AppSizes.gap + (border != null ? 8 : 0), AppSizes.gap, AppSizes.gap, AppSizes.gap), child: child),
              if (border != null) Positioned(left: 0, top: 0, bottom: 0, child: Container(width: 8, color: border)),
            ],
          ),
        ),
      ),
    );
  }
}
