import 'package:flutter/material.dart';

import '../../../../widgets/demo_page_scaffold.dart';
import '../../../../widgets/section_card.dart';

/// 学习计划 · 基础组件 · 弹窗体系
///
/// 演示 AlertDialog、SimpleDialog、ModalBottomSheet、SnackBar 四种常用弹窗。
class DialogDemo extends StatelessWidget {
  const DialogDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return const DemoPageScaffold(
      title: '弹窗体系',
      goal: '掌握确认对话框、选项对话框、模态底部弹窗和轻提示的使用场景与基本写法，学会接收弹窗的返回结果。',
      children: [
        _AlertSection(),
        _SimpleSection(),
        _BottomSheetSection(),
        _SnackBarSection(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// AlertDialog 确认对话框
// ---------------------------------------------------------------------------
class _AlertSection extends StatelessWidget {
  const _AlertSection();

  Future<void> _showDeleteDialog(BuildContext context) async {
    // showDialog 返回 Future，可接收用户点击结果
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline),
        title: const Text('确认删除？'),
        content: const Text('删除后无法恢复，请谨慎操作。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    _showSnackBar(context, confirmed == true ? '已删除' : '已取消');
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'AlertDialog 确认对话框',
      subtitle: '用于删除确认等重要操作，可返回用户选择',
      icon: Icons.warning_amber_outlined,
      child: FilledButton.tonalIcon(
        onPressed: () => _showDeleteDialog(context),
        icon: const Icon(Icons.delete_outline),
        label: const Text('弹出删除确认'),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SimpleDialog 选项对话框
// ---------------------------------------------------------------------------
class _SimpleSection extends StatelessWidget {
  const _SimpleSection();

  Future<void> _showPickerDialog(BuildContext context) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('选择排序方式'),
        children: [
          for (final option in ['最新优先', '最热优先', '价格从低到高'])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, option),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(option),
              ),
            ),
        ],
      ),
    );
    if (!context.mounted) return;
    if (selected != null) _showSnackBar(context, '选择了：$selected');
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'SimpleDialog 选项对话框',
      subtitle: '一组简单选项供用户选择',
      icon: Icons.list_alt_outlined,
      child: FilledButton.tonalIcon(
        onPressed: () => _showPickerDialog(context),
        icon: const Icon(Icons.sort),
        label: const Text('弹出选项列表'),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ModalBottomSheet 底部弹窗
// ---------------------------------------------------------------------------
class _BottomSheetSection extends StatelessWidget {
  const _BottomSheetSection();

  void _showBottomSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      // 允许弹窗内容超过半屏高度
      isScrollControlled: true,
      builder: (context) => Padding(
        // 键盘弹出时自动避让（本例无输入框，演示写法）
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            // 顶部拖拽指示条
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const ListTile(leading: Icon(Icons.share), title: Text('分享给朋友')),
            const ListTile(leading: Icon(Icons.link), title: Text('复制链接')),
            const ListTile(leading: Icon(Icons.qr_code), title: Text('生成二维码')),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'ModalBottomSheet 底部弹窗',
      subtitle: '从底部滑出的操作面板，常见于分享菜单',
      icon: Icons.vertical_align_bottom_outlined,
      child: FilledButton.tonalIcon(
        onPressed: () => _showBottomSheet(context),
        icon: const Icon(Icons.ios_share),
        label: const Text('弹出分享面板'),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SnackBar 轻提示
// ---------------------------------------------------------------------------
class _SnackBarSection extends StatelessWidget {
  const _SnackBarSection();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'SnackBar 轻提示',
      subtitle: '底部短暂提示，可附带操作按钮',
      icon: Icons.message_outlined,
      child: Wrap(
        spacing: 12,
        children: [
          FilledButton.tonal(
            onPressed: () => _showSnackBar(context, '这是一条普通提示'),
            child: const Text('普通提示'),
          ),
          FilledButton.tonal(
            onPressed: () {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: const Text('已移入回收站'),
                    action: SnackBarAction(
                      label: '撤销',
                      onPressed: () => _showSnackBar(context, '已撤销操作'),
                    ),
                  ),
                );
            },
            child: const Text('带撤销按钮'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 辅助方法
// ---------------------------------------------------------------------------
void _showSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 1)));
}
