import 'package:flutter/material.dart';

import '../data/learning_plan_data.dart';
import '../widgets/learning_entry_card.dart';
import '../widgets/section_card.dart';

/// Tab4: 动画与交互展示页面
///
/// 展示常用的动画与交互组件：AnimatedContainer、AnimatedOpacity、
/// TweenAnimationBuilder、对话框、SnackBar、底部弹窗、下拉刷新等。
class AnimationInteractionPage extends StatefulWidget {
  const AnimationInteractionPage({super.key});

  @override
  State<AnimationInteractionPage> createState() =>
      _AnimationInteractionPageState();
}

class _AnimationInteractionPageState extends State<AnimationInteractionPage>
    with TickerProviderStateMixin {
  // --- AnimatedContainer ---
  bool _containerExpanded = false;

  // --- AnimatedOpacity ---
  bool _opacityVisible = true;

  // --- AnimatedAlign ---
  bool _alignRight = false;

  // --- 进度条 ---
  double _progress = 0.3;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 学习计划入口：点击进入本分类的章节列表（二级页面）
        const LearningEntryCard(chapter: LearningPlanData.animationChapter),
        _AnimatedContainerSection(
          expanded: _containerExpanded,
          onToggle: () => setState(() => _containerExpanded = !_containerExpanded),
        ),
        _AnimatedOpacitySection(
          visible: _opacityVisible,
          onToggle: () => setState(() => _opacityVisible = !_opacityVisible),
        ),
        _AnimatedAlignSection(
          alignRight: _alignRight,
          onToggle: () => setState(() => _alignRight = !_alignRight),
        ),
        _TweenAnimationSection(),
        _ProgressSection(
          progress: _progress,
          onChanged: (v) => setState(() => _progress = v),
        ),
        _DialogSection(parentContext: context),
        _BottomSheetSection(parentContext: context),
        _RefreshSection(),
        _ExplicitAnimationSection(vsync: this),
        const _AnimatedSwitcherSection(),
        const _AnimatedIconSection(),
        _HeroSection(parentContext: context),
        const _DismissibleSection(),
        const _PageViewSection(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// AnimatedContainer 区域
// ---------------------------------------------------------------------------
class _AnimatedContainerSection extends StatelessWidget {
  const _AnimatedContainerSection({
    required this.expanded,
    required this.onToggle,
  });

  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: 'AnimatedContainer',
      subtitle: '尺寸 / 颜色 / 圆角动画',
      icon: Icons.crop_free,
      child: Column(
        children: [
          // 注意：AnimatedContainer 不能在「有限值 ↔ double.infinity」之间做插值
          // 动画，否则动画中间帧会触发 "Cannot interpolate between finite
          // constraints and unbounded constraints" 断言错误。这里用 LayoutBuilder
          // 拿到实际可用宽度，让宽度动画到一个具体数值。
          LayoutBuilder(
            builder: (context, constraints) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOutCubic,
                width: expanded ? constraints.maxWidth : 100,
                height: expanded ? 120 : 80,
                decoration: BoxDecoration(
                  color: expanded
                      ? theme.colorScheme.primary
                      : theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(expanded ? 24 : 12),
                ),
                child: Center(
                  child: Text(
                    expanded ? '展开' : '收起',
                    style: TextStyle(
                      color: expanded
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.primary,
                      fontSize: expanded ? 20 : 14,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: onToggle,
            icon: Icon(expanded ? Icons.compress : Icons.expand),
            label: Text(expanded ? '收起' : '展开'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AnimatedOpacity 区域
// ---------------------------------------------------------------------------
class _AnimatedOpacitySection extends StatelessWidget {
  const _AnimatedOpacitySection({
    required this.visible,
    required this.onToggle,
  });

  final bool visible;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: 'AnimatedOpacity',
      subtitle: '淡入淡出动画',
      icon: Icons.visibility,
      child: Column(
        children: [
          AnimatedOpacity(
            opacity: visible ? 1.0 : 0.2,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiary,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.favorite,
                  color: theme.colorScheme.onTertiary, size: 40),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: onToggle,
            icon: Icon(visible ? Icons.visibility_off : Icons.visibility),
            label: Text(visible ? '隐藏' : '显示'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AnimatedAlign 区域
// ---------------------------------------------------------------------------
class _AnimatedAlignSection extends StatelessWidget {
  const _AnimatedAlignSection({
    required this.alignRight,
    required this.onToggle,
  });

  final bool alignRight;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: 'AnimatedAlign',
      subtitle: '位置移动动画',
      icon: Icons.align_horizontal_center,
      child: Column(
        children: [
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: AnimatedAlign(
              alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
              duration: const Duration(milliseconds: 400),
              curve: Curves.bounceOut,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Icon(Icons.directions_run,
                    color: theme.colorScheme.primary, size: 32),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: onToggle,
            icon: const Icon(Icons.swap_horiz),
            label: Text(alignRight ? '向左' : '向右'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TweenAnimationBuilder 区域
// ---------------------------------------------------------------------------
class _TweenAnimationSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      key: const ValueKey('tween'),
      title: 'TweenAnimationBuilder',
      subtitle: '自定义补间动画',
      icon: Icons.auto_graph,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(seconds: 2),
        curve: Curves.elasticOut,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: Transform.rotate(
              angle: value * 2 * 3.14159,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.tertiary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.star,
                    color: theme.colorScheme.onPrimary, size: 40),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 进度条区域
// ---------------------------------------------------------------------------
class _ProgressSection extends StatelessWidget {
  const _ProgressSection({
    required this.progress,
    required this.onChanged,
  });

  final double progress;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: '进度指示器',
      subtitle: 'LinearProgressIndicator / CircularProgressIndicator',
      icon: Icons.pending,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('进度: ${(progress * 100).round()}%'),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                height: 48,
                width: 48,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 4,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Slider(
                  value: progress,
                  min: 0,
                  max: 1,
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 对话框区域
// ---------------------------------------------------------------------------
class _DialogSection extends StatelessWidget {
  const _DialogSection({required this.parentContext});

  final BuildContext parentContext;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '对话框',
      subtitle: 'AlertDialog / SimpleDialog',
      icon: Icons.chat_bubble_outline,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          FilledButton(
            onPressed: () => _showAlertDialog(parentContext),
            child: const Text('AlertDialog'),
          ),
          OutlinedButton(
            onPressed: () => _showSimpleDialog(parentContext),
            child: const Text('SimpleDialog'),
          ),
          TextButton(
            onPressed: () => _showFullScreenDialog(parentContext),
            child: const Text('全屏页面'),
          ),
        ],
      ),
    );
  }

  void _showAlertDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.info_outline),
        title: const Text('提示'),
        content: const Text('这是一个 AlertDialog 对话框，用于确认操作或展示重要信息。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  void _showSimpleDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('请选择'),
        children: ['选项 A', '选项 B', '选项 C']
            .map((e) => SimpleDialogOption(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showSnackBar(context, '选择了 $e');
                  },
                  child: Text(e),
                ))
            .toList(),
      ),
    );
  }

  void _showFullScreenDialog(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => Scaffold(
          appBar: AppBar(title: const Text('全屏页面')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.open_in_full, size: 64),
                const SizedBox(height: 16),
                const Text('这是一个全屏页面 (fullscreenDialog)'),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('返回'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 底部弹窗区域
// ---------------------------------------------------------------------------
class _BottomSheetSection extends StatelessWidget {
  const _BottomSheetSection({required this.parentContext});

  final BuildContext parentContext;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '底部弹窗',
      subtitle: 'ModalBottomSheet / SnackBar',
      icon: Icons.vertical_align_bottom,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          FilledButton(
            onPressed: () => _showBottomSheet(parentContext),
            child: const Text('BottomSheet'),
          ),
          OutlinedButton(
            onPressed: () => _showSnackBar(parentContext, '这是一条 SnackBar 消息'),
            child: const Text('SnackBar'),
          ),
          TextButton(
            onPressed: () => _showSnackBar(
              parentContext,
              '带操作按钮的 SnackBar',
              action: SnackBarAction(
                label: '撤销',
                onPressed: () => _showSnackBar(parentContext, '已撤销'),
              ),
            ),
            child: const Text('Action SnackBar'),
          ),
        ],
      ),
    );
  }

  void _showBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('底部弹窗',
                    style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text('这是一个 ModalBottomSheet，常用于展示操作菜单或补充信息。'),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.share),
                  title: const Text('分享'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showSnackBar(context, '点击了分享');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.link),
                  title: const Text('复制链接'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showSnackBar(context, '已复制链接');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete,
                      color: Colors.red),
                  title: const Text('删除', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showSnackBar(context, '点击了删除');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 下拉刷新区域
// ---------------------------------------------------------------------------
class _RefreshSection extends StatefulWidget {
  @override
  State<_RefreshSection> createState() => _RefreshSectionState();
}

class _RefreshSectionState extends State<_RefreshSection> {
  final List<int> _items = List.generate(5, (i) => i);
  bool _refreshing = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: 'RefreshIndicator',
      subtitle: '下拉刷新列表',
      icon: Icons.refresh,
      child: SizedBox(
        height: 200,
        child: RefreshIndicator(
          onRefresh: () async {
            setState(() => _refreshing = true);
            await Future.delayed(const Duration(seconds: 1));
            setState(() {
              _items.insert(0, _items.length);
              _refreshing = false;
            });
          },
          child: ListView.builder(
            itemCount: _items.length,
            itemBuilder: (context, index) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text('${_items[index]}',
                      style: TextStyle(color: theme.colorScheme.primary)),
                ),
                title: Text('Item ${_items[index]}'),
                subtitle: Text(_refreshing && index == 0 ? '刷新中...' : '下拉可刷新'),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 辅助方法
// ---------------------------------------------------------------------------
void _showSnackBar(BuildContext context, String message, {SnackBarAction? action}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        action: action,
      ),
    );
}

// ---------------------------------------------------------------------------
// AnimationController 显式动画区域
// ---------------------------------------------------------------------------

/// 演示 AnimationController 显式动画：
/// - 需要 TickerProviderStateMixin 提供 vsync
/// - forward() 正向播放 / reverse() 反向播放 / repeat() 循环
/// - 配合 AnimatedBuilder 监听动画值变化来重建 UI
class _ExplicitAnimationSection extends StatefulWidget {
  const _ExplicitAnimationSection({required this.vsync});

  final TickerProvider vsync;

  @override
  State<_ExplicitAnimationSection> createState() =>
      _ExplicitAnimationSectionState();
}

class _ExplicitAnimationSectionState extends State<_ExplicitAnimationSection> {
  late final AnimationController _controller;
  late final Animation<double> _rotateAnim;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: widget.vsync,
      duration: const Duration(seconds: 2),
    );
    // Tween 定义动画的起始值和结束值
    _rotateAnim = Tween(begin: 0.0, end: 2 * 3.14159).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
    _scaleAnim = Tween(begin: 0.6, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose(); // 必须释放，防止内存泄漏
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: 'AnimationController',
      subtitle: '显式动画 / forward / reverse / repeat',
      icon: Icons.motion_photos_on,
      child: Column(
        children: [
          SizedBox(
            height: 100,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _rotateAnim.value,
                  child: Transform.scale(
                    scale: _scaleAnim.value,
                    child: child,
                  ),
                );
              },
              // child 不依赖动画值，只构建一次，提升性能
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [theme.colorScheme.secondary,
                        theme.colorScheme.primary],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.flutter_dash,
                    color: theme.colorScheme.onPrimary, size: 32),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => _controller.forward(),
                icon: const Icon(Icons.play_arrow),
                label: const Text('播放'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _controller.reverse(),
                icon: const Icon(Icons.replay),
                label: const Text('反向'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _controller.repeat(reverse: true),
                icon: const Icon(Icons.repeat),
                label: const Text('循环'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _controller.stop(),
                icon: const Icon(Icons.stop),
                label: const Text('停止'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AnimatedSwitcher 区域
// ---------------------------------------------------------------------------

/// 演示 AnimatedSwitcher：
/// - 当 child 变化时，自动在新旧组件之间执行过渡动画
/// - 新旧组件必须 key 不同，否则不会触发切换动画
class _AnimatedSwitcherSection extends StatefulWidget {
  const _AnimatedSwitcherSection();

  @override
  State<_AnimatedSwitcherSection> createState() =>
      _AnimatedSwitcherSectionState();
}

class _AnimatedSwitcherSectionState extends State<_AnimatedSwitcherSection> {
  int _count = 0;

  static const _icons = [
    Icons.looks_one, Icons.looks_two, Icons.looks_3,
    Icons.looks_4, Icons.looks_5,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: 'AnimatedSwitcher',
      subtitle: '组件切换过渡动画',
      icon: Icons.switch_access_shortcut,
      child: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            // 自定义过渡: 缩放 + 淡入淡出
            transitionBuilder: (child, animation) {
              return ScaleTransition(scale: animation, child: child);
            },
            child: Container(
              // key 变化才会触发切换动画
              key: ValueKey(_count),
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _icons[_count % _icons.length],
                size: 40,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: () => setState(() => _count++),
            icon: const Icon(Icons.skip_next),
            label: const Text('切换'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AnimatedIcon 区域
// ---------------------------------------------------------------------------

/// 演示 AnimatedIcon：
/// - Material 内置的变形图标动画（如 menu ↔ close）
/// - 通过 AnimationController 的 progress 控制变形进度
class _AnimatedIconSection extends StatefulWidget {
  const _AnimatedIconSection();

  @override
  State<_AnimatedIconSection> createState() => _AnimatedIconSectionState();
}

class _AnimatedIconSectionState extends State<_AnimatedIconSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: 'AnimatedIcon',
      subtitle: 'menu ↔ close 变形图标',
      icon: Icons.animation,
      child: Column(
        children: [
          IconButton(
            iconSize: 48,
            color: theme.colorScheme.primary,
            icon: AnimatedIcon(
              icon: AnimatedIcons.menu_close,
              progress: _controller,
            ),
            onPressed: () {
              setState(() => _isOpen = !_isOpen);
              _isOpen ? _controller.forward() : _controller.reverse();
            },
          ),
          const SizedBox(height: 8),
          Text(_isOpen ? '状态: 已展开 (close)' : '状态: 已收起 (menu)'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero 动画区域
// ---------------------------------------------------------------------------

/// 演示 Hero 共享元素动画：
/// - 两个页面中使用相同 tag 的 Hero 组件
/// - 页面跳转时自动执行“飞行”过渡动画
class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.parentContext});

  final BuildContext parentContext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: 'Hero 动画',
      subtitle: '跨页面共享元素过渡',
      icon: Icons.flight_takeoff,
      child: Row(
        children: [
          Hero(
            tag: 'hero-demo',
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [theme.colorScheme.primary,
                      theme.colorScheme.tertiary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.rocket_launch,
                  color: theme.colorScheme.onPrimary, size: 32),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _navigateToDetail(parentContext),
              icon: const Icon(Icons.open_in_new),
              label: const Text('点击飞行'),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToDetail(BuildContext context) {
    final theme = Theme.of(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          appBar: AppBar(title: const Text('Hero 详情页')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Hero(
                  tag: 'hero-demo', // 与上一页相同的 tag
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [theme.colorScheme.primary,
                            theme.colorScheme.tertiary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: Icon(Icons.rocket_launch,
                        color: theme.colorScheme.onPrimary, size: 80),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('相同的 Hero tag 实现了跨页面飞行动画'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('飞回去'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dismissible 区域
// ---------------------------------------------------------------------------

/// 演示 Dismissible 滑动删除：
/// - 包裹列表项，左右滑动即可删除
/// - background 显示滑动时露出的背景
/// - onDismissed 在删除后回调，需从数据源移除对应数据
class _DismissibleSection extends StatefulWidget {
  const _DismissibleSection();

  @override
  State<_DismissibleSection> createState() => _DismissibleSectionState();
}

class _DismissibleSectionState extends State<_DismissibleSection> {
  final List<String> _fruits = ['🍎 苹果', '🍌 香蕉', '🍊 橙子', '🍇 葡萄', '🍉 西瓜'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: 'Dismissible',
      subtitle: '滑动删除列表项',
      icon: Icons.swipe,
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: _fruits.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.delete_sweep,
                            size: 40, color: theme.colorScheme.outline),
                        const SizedBox(height: 8),
                        const Text('全部删完了'),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => setState(() {
                            _fruits.addAll(['🍎 苹果', '🍌 香蕉', '🍊 橙子', '🍇 葡萄', '🍉 西瓜']);
                          }),
                          icon: const Icon(Icons.restore),
                          label: const Text('恢复列表'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _fruits.length,
                    itemBuilder: (context, index) {
                      final fruit = _fruits[index];
                      return Dismissible(
                        // key 必须唯一，用于识别哪个组件被删除
                        key: ValueKey(fruit),
                        direction: DismissDirection.endToStart, // 只允许向左滑
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.error,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.delete,
                              color: theme.colorScheme.onError),
                        ),
                        onDismissed: (direction) {
                          setState(() => _fruits.removeAt(index));
                          _showSnackBar(context, '删除了 $fruit');
                        },
                        child: Card(
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          child: ListTile(
                            dense: true,
                            title: Text(fruit),
                            trailing: Icon(Icons.chevron_left,
                                color: theme.colorScheme.outline),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
          Text('← 向左滑动删除',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PageView 区域
// ---------------------------------------------------------------------------

/// 演示 PageView 分页滑动：
/// - PageController 控制页面切换与监听
/// - viewportFraction 可以让相邻页面露出一部分
/// - 配合 AnimatedBuilder 实现自定义页面指示器
class _PageViewSection extends StatefulWidget {
  const _PageViewSection();

  @override
  State<_PageViewSection> createState() => _PageViewSectionState();
}

class _PageViewSectionState extends State<_PageViewSection> {
  final PageController _pageController = PageController(viewportFraction: 0.85);
  int _currentPage = 0;

  static const _pageData = [
    (icon: Icons.palette, title: '主题', desc: 'Material 3 动态配色'),
    (icon: Icons.devices, title: '跨平台', desc: '一套代码多端运行'),
    (icon: Icons.speed, title: '高性能', desc: '自绘引擎 60fps 渲染'),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: 'PageView',
      subtitle: '分页滑动 / PageController / 指示器',
      icon: Icons.view_carousel,
      child: Column(
        children: [
          SizedBox(
            height: 140,
            child: PageView.builder(
              controller: _pageController,
              itemCount: _pageData.length,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemBuilder: (context, index) {
                final (icon: icon, title: title, desc: desc) = _pageData[index];
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: index == _currentPage
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 40,
                          color: theme.colorScheme.primary),
                      const SizedBox(height: 8),
                      Text(title,
                          style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(desc,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          // 自定义圆点指示器
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_pageData.length, (index) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentPage == index ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
