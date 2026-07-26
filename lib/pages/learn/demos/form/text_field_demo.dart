import 'package:flutter/material.dart';

import '../../../../widgets/demo_page_scaffold.dart';
import '../../../../widgets/section_card.dart';

/// 学习计划 · 表单组件 · 输入框深入
///
/// 演示 InputDecoration 装饰、TextEditingController 控制器、FocusNode 焦点控制与键盘配置。
class TextFieldDemo extends StatefulWidget {
  const TextFieldDemo({super.key});

  @override
  State<TextFieldDemo> createState() => _TextFieldDemoState();
}

class _TextFieldDemoState extends State<TextFieldDemo> {
  final _controller = TextEditingController();
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  bool _obscure = true;
  String _submitted = '';

  @override
  void dispose() {
    // 控制器与焦点节点必须手动释放，避免内存泄漏
    _controller.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() => _submitted = _controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return DemoPageScaffold(
      title: '输入框深入',
      goal: '掌握 InputDecoration 常用装饰属性，学会用 TextEditingController 读取与清空内容，用 FocusNode 控制焦点跳转，以及配置键盘类型与密码可见切换。',
      children: [
        const _DecorationSection(),
        _ControllerSection(controller: _controller, submitted: _submitted, onSubmit: _submit),
        _FocusSection(nameFocus: _nameFocus, emailFocus: _emailFocus),
        _KeyboardSection(
          obscure: _obscure,
          onToggleObscure: () => setState(() => _obscure = !_obscure),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 装饰定制
// ---------------------------------------------------------------------------
class _DecorationSection extends StatelessWidget {
  const _DecorationSection();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '装饰定制',
      subtitle: 'label / hint / 前后图标 / 边框样式',
      icon: Icons.border_color_outlined,
      child: const Column(
        children: [
          TextField(
            decoration: InputDecoration(
              labelText: '用户名',
              hintText: '请输入 4-16 位字符',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              labelText: '搜索',
              prefixIcon: Icon(Icons.search),
              suffixIcon: Icon(Icons.mic),
              // 填充风格的圆角输入框，无边框线
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(28)),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              labelText: '带辅助说明',
              helperText: 'helperText 显示在输入框下方',
              border: OutlineInputBorder(),
              // 计数器
              counterText: '0 / 20',
            ),
            maxLength: 20,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 控制器
// ---------------------------------------------------------------------------
class _ControllerSection extends StatelessWidget {
  const _ControllerSection({
    required this.controller,
    required this.submitted,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final String submitted;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: 'TextEditingController 控制器',
      subtitle: '读取 / 清空 / 程序化设置输入内容',
      icon: Icons.settings_remote_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: '留言',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: controller.clear,
              ),
            ),
            onSubmitted: (_) => onSubmit(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.tonal(onPressed: onSubmit, child: const Text('读取内容')),
              const SizedBox(width: 12),
              FilledButton.tonal(
                // 程序化设置内容并移动光标到末尾
                onPressed: () {
                  controller.text = '这是代码填入的内容';
                  controller.selection = TextSelection.collapsed(offset: controller.text.length);
                },
                child: const Text('代码填入'),
              ),
            ],
          ),
          if (submitted.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('读取结果：$submitted', style: TextStyle(color: theme.colorScheme.primary)),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 焦点控制
// ---------------------------------------------------------------------------
class _FocusSection extends StatelessWidget {
  const _FocusSection({required this.nameFocus, required this.emailFocus});

  final FocusNode nameFocus;
  final FocusNode emailFocus;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'FocusNode 焦点控制',
      subtitle: '键盘「下一项」按钮自动跳转焦点',
      icon: Icons.switch_access_shortcut_outlined,
      child: Column(
        children: [
          TextField(
            focusNode: nameFocus,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: '姓名',
              border: OutlineInputBorder(),
            ),
            // 点击键盘「下一项」时把焦点转移到邮箱输入框
            onSubmitted: (_) => emailFocus.requestFocus(),
          ),
          const SizedBox(height: 12),
          TextField(
            focusNode: emailFocus,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: '邮箱',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => emailFocus.unfocus(),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 键盘配置
// ---------------------------------------------------------------------------
class _KeyboardSection extends StatelessWidget {
  const _KeyboardSection({required this.obscure, required this.onToggleObscure});

  final bool obscure;
  final VoidCallback onToggleObscure;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '键盘类型与密码输入',
      subtitle: 'keyboardType / obscureText / 可见性切换',
      icon: Icons.keyboard_outlined,
      child: Column(
        children: [
          const TextField(
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: '手机号（数字键盘）',
              prefixIcon: Icon(Icons.phone_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            obscureText: obscure,
            decoration: InputDecoration(
              labelText: '密码',
              prefixIcon: const Icon(Icons.lock_outline),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: onToggleObscure,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
