import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../widgets/celebrate.dart';
import '../widgets/common.dart';
import 'classify_screen.dart';
import 'discard_screen.dart';
import 'item_detail_screen.dart';
import 'item_list_screen.dart';
import 'notices_screen.dart';
import 'progress_screen.dart';
import 'register_screen.dart';
import 'sell_screen.dart';
import 'settings_screen.dart';

void go(BuildContext context, Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

/// 결정하고 축하하고 되돌리기를 보여 주는 공용 동작
Future<void> decideWithUndo(BuildContext context, Item item, Decision d) async {
  final s = context.read<AppState>();
  final before = await s.decide(item, d);
  if (!context.mounted) return;
  celebrate(context, decision: d, message: '${d.label}(으)로 정했어요');
  toast(context, '"${item.name}" → ${d.label}', actionLabel: '되돌리기', onAction: () => s.restore(before));
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showMissed());
  }

  /// 앱을 열면 밀린 알림(1년 이동 등)을 먼저 보여 줌
  void _showMissed() {
    final s = context.read<AppState>();
    // 오늘 아침 알림이 새로 왔으면 음성으로도 안내
    if (s.unread.any((n) => n.kind == 'daily')) s.say(s.todaySpeech());
    final important = s.unread.where((n) => n.kind == 'one_year_moved' || n.kind == 'one_year_warn').toList();
    if (important.isEmpty) return;
    toast(context, important.first.title, actionLabel: '알림 보기', onAction: () => go(context, const NoticesScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final p = context.palette;
    final st = s.stats;
    return Scaffold(
      appBar: AppBar(
        title: const Text('비우기 비서'),
        actions: [
          if (s.hasUpdate)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: ActionChip(
                backgroundColor: p.attention,
                label: Text(
                  '새 버전 있어요',
                  style: TextStyle(color: p.onAttention, fontWeight: FontWeight.w700),
                ),
                onPressed: () => go(context, const SettingsScreen()),
              ),
            ),
          IconButton(
            tooltip: '알림',
            iconSize: 30,
            onPressed: () => go(context, const NoticesScreen()),
            icon: Badge(isLabelVisible: s.unread.isNotEmpty, label: Text('${s.unread.length}'), child: const Icon(Icons.notifications_rounded)),
          ),
          IconButton(tooltip: '설정', iconSize: 30, onPressed: () => go(context, const SettingsScreen()), icon: const Icon(Icons.settings_rounded)),
        ],
      ),
      body: SafeArea(
        child: ListView(
          key: const PageStorageKey('home_1'),
          padding: const EdgeInsets.fromLTRB(AppSizes.page, 0, AppSizes.page, 120),
          children: [
            if (s.unread.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.gap),
                child: BigButton(
                  label: '밀린 알림 ${s.unread.length}개 보기',
                  emoji: 'bell',
                  color: p.attention,
                  textColor: p.onAttention,
                  onTap: () => go(context, const NoticesScreen()),
                ),
              ),
            const FirstTimeTip(id: 'home', text: '맨 위 "오늘 할 일"에서 하루에 물건 하나만 정하면 돼요. 아래 큰 동그라미 버튼으로 물건을 찍어 등록해요.'),
            _TodayCard(item: s.today),
            const SizedBox(height: AppSizes.gap),
            Tile3D(emoji: 'camera', title: '물건 등록', subtitle: '사진·영상으로 한 번에 등록해요', color: p.accent, onTap: () => go(context, const RegisterScreen())),
            const SizedBox(height: AppSizes.gap),
            Tile3D(
              emoji: 'clipboard',
              title: '정리하기',
              subtitle: '밀어서 세 가지로 나눠요',
              color: p.progress,
              badge: (st?.undecided ?? 0) > 0 ? '${st!.undecided}' : null,
              onTap: () => go(context, const ClassifyScreen()),
            ),
            const SizedBox(height: AppSizes.gap),
            Tile3D(emoji: 'sell', title: '판매 도우미', subtitle: '판매글을 만들고 복사해요', color: p.sell, onTap: () => go(context, const SellScreen())),
            const SizedBox(height: AppSizes.gap),
            Tile3D(emoji: 'discard', title: '폐기 도우미', subtitle: '버리는 방법·나눔을 알려 줘요', color: p.discard, onTap: () => go(context, const DiscardScreen())),
            const SizedBox(height: AppSizes.gap),
            Tile3D(emoji: 'chart', title: '진행 현황', subtitle: '얼마나 비웠는지 봐요', color: p.use, onTap: () => go(context, const ProgressScreen())),
            const SizedBox(height: AppSizes.gap),
            Tile3D(
              emoji: 'package',
              title: '모든 물건',
              subtitle: '${st?.total ?? 0}개 · 찾기와 고치기',
              color: p.primary,
              onTap: () => go(context, const ItemListScreen()),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: CaptureButton(emoji: 'camera', label: '찍어서 등록', onTap: () => go(context, const RegisterScreen(autoStart: true))),
    );
  }
}

class _TodayCard extends StatelessWidget {
  final Item? item;
  const _TodayCard({required this.item});
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = context.read<AppState>();
    final it = item;
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppSizes.radius),
        border: Border.all(color: p.attention, width: AppSizes.cardBorder),
        boxShadow: AppShadows.raised(p),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSizes.gap),
            child: Row(
              children: [
                const Emoji3D('calendar', size: 40),
                const SizedBox(width: 10),
                Expanded(child: Text('오늘 할 일', style: Theme.of(context).textTheme.titleLarge)),
                IconButton(tooltip: '읽어 주기', iconSize: 32, icon: const Icon(Icons.volume_up_rounded), onPressed: () => s.say(s.todaySpeech())),
              ],
            ),
          ),
          if (it == null)
            EmptyState(
              message: s.items.isEmpty ? '첫 물건을 찍어 보세요' : '정할 물건을 다 정했어요! 새 물건을 등록해 보세요.',
              mood: s.items.isEmpty ? MascotMood.hello : MascotMood.celebrate,
              buttonLabel: '첫 물건 찍기',
              onButton: () => go(context, const RegisterScreen(autoStart: true)),
            )
          else ...[
            GestureDetector(
              onTap: () => go(context, ItemDetailScreen(itemId: it.id!)),
              child: SizedBox(height: 220, child: ItemPhoto(it, height: 220, full: true)),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSizes.gap),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('오늘은 이 물건 하나만 정해 보세요', style: TextStyle(color: p.muted, fontSize: 16)),
                  Text(it.name, style: Theme.of(context).textTheme.headlineMedium),
                  if (it.aiSuggestion != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('추천: ${it.aiSuggestion!.label} — ${it.aiReason}', style: const TextStyle(fontSize: 16)),
                    ),
                  const SizedBox(height: AppSizes.gap),
                  DecisionButtons(onPick: (d) => decideWithUndo(context, it, d)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
