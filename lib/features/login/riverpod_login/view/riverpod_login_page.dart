import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/models/user.dart';
import '../viewmodel/login_view_model.dart';

/// Riverpod 版登录页面（View 层）
///
/// MVVM 中的 View 层，职责仅有两件事：
/// 1. 把用户操作转成方法调用：`ref.read(loginViewModelProvider.notifier).xxx()`
/// 2. 监听 ViewModel 的状态并渲染：`ref.watch` / `ref.listen`
///
/// [ConsumerStatefulWidget] 提供 `ref` 与生命周期感知；
/// 页面内不包含任何业务逻辑，全部收敛在 LoginViewModel 中。
class RiverpodLoginPage extends ConsumerStatefulWidget {
  const RiverpodLoginPage({super.key});

  @override
  ConsumerState<RiverpodLoginPage> createState() => _RiverpodLoginPageState();
}

class _RiverpodLoginPageState extends ConsumerState<RiverpodLoginPage> {
  /// 输入框控制器属于 View 的展示细节，不放进 ViewModel 状态
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ref.watch：订阅状态变化，状态更新时自动重建
    final state = ref.watch(loginViewModelProvider);

    // ref.listen：只处理「一次性副作用」（弹 SnackBar），不参与构建
    ref.listen<LoginState>(loginViewModelProvider, (previous, next) {
      if (next.status == LoginStatus.failure) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(next.errorMessage ?? '登录失败')),
          );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Riverpod 实现 · 登录')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: state.isLoggedIn
                  ? _SuccessCard(user: state.user!)
                  : _buildForm(context, state),
            ),
          ),
        ),
      ),
    );
  }

  /// 登录表单
  Widget _buildForm(BuildContext context, LoginState state) {
    final submitting = state.status == LoginStatus.submitting;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.water_drop, size: 56),
        const SizedBox(height: 12),
        Text(
          'Riverpod 版模拟登录',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _usernameController,
          enabled: !submitting,
          decoration: const InputDecoration(
            labelText: '账号',
            prefixIcon: Icon(Icons.person_outline),
            border: OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.next,
          // View → ViewModel：直接调用方法（区别于 Bloc 的 add 事件）
          onChanged: (value) =>
              ref.read(loginViewModelProvider.notifier).usernameChanged(value),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          enabled: !submitting,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: '密码',
            prefixIcon: Icon(Icons.lock_outline),
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) {
            if (state.canSubmit) {
              ref.read(loginViewModelProvider.notifier).submitLogin();
            }
          },
          onChanged: (value) =>
              ref.read(loginViewModelProvider.notifier).passwordChanged(value),
        ),
        const SizedBox(height: 8),
        if (state.errorMessage != null) ...[
          Text(
            state.errorMessage!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 16),
        FilledButton(
          // 按钮可用性完全由状态派生（canSubmit），View 不做判断
          onPressed: state.canSubmit
              ? () => ref.read(loginViewModelProvider.notifier).submitLogin()
              : null,
          child: submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('登录'),
        ),
        const SizedBox(height: 16),
        Text(
          '演示账号：admin / 123456 或 flutter / dart2026',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// 登录成功后的用户卡片
class _SuccessCard extends ConsumerWidget {
  const _SuccessCard({required this.user});

  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 32,
              child: Icon(Icons.person, size: 32),
            ),
            const SizedBox(height: 16),
            Text(user.nickname, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              '账号：${user.username}　·　ID：${user.id}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '本卡片由 loginViewModelProvider 的状态 (user, status) 驱动渲染',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () =>
                  ref.read(loginViewModelProvider.notifier).logout(),
              child: const Text('退出登录'),
            ),
          ],
        ),
      ),
    );
  }
}
