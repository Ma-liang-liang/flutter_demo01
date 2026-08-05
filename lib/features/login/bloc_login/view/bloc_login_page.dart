import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../common/models/user.dart';
import '../viewmodel/login_bloc.dart';

/// Bloc 版登录页面（View 层）
///
/// MVVM 中的 View 层，职责仅有两件事：
/// 1. 把用户操作转成事件发给 ViewModel：`context.read<LoginBloc>().add(...)`
/// 2. 监听 ViewModel 的状态并渲染：`BlocBuilder` / `BlocListener`
///
/// 页面内不包含任何业务逻辑，全部收敛在 [LoginBloc] 中。
class BlocLoginPage extends StatelessWidget {
  const BlocLoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    // BlocProvider 负责创建并管理 LoginBloc 的生命周期，
    // 页面销毁时自动 close（取消订阅、释放资源）
    return BlocProvider(
      create: (_) => LoginBloc(),
      child: const _LoginView(),
    );
  }
}

/// 真正的视图实现（与 Provider 分离，便于 BlocProvider 之下查找）
class _LoginView extends StatefulWidget {
  const _LoginView();

  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
  /// 输入框控制器属于 View 的展示细节，不放进 Bloc 状态
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bloc 实现 · 登录')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              // BlocListener 只处理「一次性副作用」（弹 SnackBar），不参与构建
              child: BlocListener<LoginBloc, LoginState>(
                listenWhen: (previous, current) =>
                    current.status == LoginStatus.failure,
                listener: (context, state) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(content: Text(state.errorMessage ?? '登录失败')),
                    );
                },
                // BlocBuilder 根据状态重建 UI：登录成功 → 用户卡片，否则 → 表单
                child: BlocBuilder<LoginBloc, LoginState>(
                  builder: (context, state) {
                    if (state.isLoggedIn) {
                      return _SuccessCard(user: state.user!);
                    }
                    return _buildForm(context, state);
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 登录表单
  Widget _buildForm(BuildContext context, LoginState state) {
    final submitting = state.status == LoginStatus.submitting;

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.lock_outline, size: 56),
          const SizedBox(height: 12),
          Text(
            'Bloc 版模拟登录',
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
            // View → ViewModel：发送事件而非调用业务方法
            onChanged: (value) =>
                context.read<LoginBloc>().add(UsernameChanged(value)),
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
                context.read<LoginBloc>().add(const LoginSubmitted());
              }
            },
            onChanged: (value) =>
                context.read<LoginBloc>().add(PasswordChanged(value)),
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
                ? () =>
                      context.read<LoginBloc>().add(const LoginSubmitted())
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
      ),
    );
  }
}

/// 登录成功后的用户卡片
class _SuccessCard extends StatelessWidget {
  const _SuccessCard({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
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
              '本卡片由 LoginBloc 的 LoginState(user, status) 驱动渲染',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () =>
                  context.read<LoginBloc>().add(const LogoutRequested()),
              child: const Text('退出登录'),
            ),
          ],
        ),
      ),
    );
  }
}
