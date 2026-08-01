import 'package:flutter_riverpod/flutter_riverpod.dart';

// ===========================================================================
// NotifierProvider —— 复杂状态管理（Riverpod 2.x 推荐写法）
//
// NotifierProvider 配合 Notifier 类使用，适合管理需要复杂业务逻辑的状态：
//   - Todo 列表（增删改查）
//   - 购物车（添加 / 删除 / 计算总价）
//   - 表单状态（多字段联动校验）
//
// 与 StateProvider 的区别：
//   - StateProvider：直接修改 .state，适合简单赋值
//   - NotifierProvider：封装业务方法，状态变更逻辑集中管理
//
// Notifier 类通过 build() 返回初始状态，方法中通过 state = ... 更新。
// ===========================================================================

/// ---------- Todo 模型 ----------
class Todo {
  const Todo({
    required this.id,
    required this.title,
    this.completed = false,
  });

  final String id;
  final String title;
  final bool completed;

  Todo copyWith({String? title, bool? completed}) {
    return Todo(
      id: id,
      title: title ?? this.title,
      completed: completed ?? this.completed,
    );
  }
}

/// ---------- Todo 列表 Notifier ----------
///
/// 继承 `Notifier<List<Todo>>`，build() 返回初始状态。
/// 对外暴露 add / toggle / remove 方法，内部通过 state = ... 更新。
class TodoListNotifier extends Notifier<List<Todo>> {
  @override
  List<Todo> build() {
    // 初始数据
    return [
      const Todo(id: '1', title: '学习 Riverpod 基础'),
      const Todo(id: '2', title: '掌握 Provider 用法', completed: true),
      const Todo(id: '3', title: '实践 NotifierProvider'),
    ];
  }

  /// 添加 Todo
  void add(String title) {
    if (title.trim().isEmpty) return;
    final todo = Todo(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title.trim(),
    );
    state = [...state, todo];
  }

  /// 切换完成状态
  void toggle(String id) {
    state = [
      for (final todo in state)
        if (todo.id == id) todo.copyWith(completed: !todo.completed) else todo,
    ];
  }

  /// 删除 Todo
  void remove(String id) {
    state = state.where((todo) => todo.id != id).toList();
  }

  /// 清除已完成
  void clearCompleted() {
    state = state.where((todo) => !todo.completed).toList();
  }
}

/// Todo 列表 Provider
///
/// 使用方式：
///   ref.watch(todoListProvider) → `List<Todo>`  （读取状态）
///   ref.read(todoListProvider.notifier).add('...')  （调用方法）
final todoListProvider =
    NotifierProvider<TodoListNotifier, List<Todo>>(TodoListNotifier.new);

/// ---------- 派生 Provider：未完成数量 ----------
///
/// 依赖 todoListProvider，自动计算未完成的 Todo 数量。
final incompleteCountProvider = Provider<int>((ref) {
  final todos = ref.watch(todoListProvider);
  return todos.where((t) => !t.completed).length;
});

/// ---------- 派生 Provider：完成数量 ----------
final completeCountProvider = Provider<int>((ref) {
  final todos = ref.watch(todoListProvider);
  return todos.where((t) => t.completed).length;
});

/// ---------- 购物车 Notifier（展示带计算逻辑的状态管理）----------
class CartItem {
  const CartItem({required this.id, required this.name, required this.price, this.quantity = 1});

  final String id;
  final String name;
  final double price;
  final int quantity;

  CartItem copyWith({int? quantity}) {
    return CartItem(id: id, name: name, price: price, quantity: quantity ?? this.quantity);
  }
}

class CartNotifier extends Notifier<List<CartItem>> {
  @override
  List<CartItem> build() {
    return [
      const CartItem(id: 'p1', name: '咖啡', price: 28),
      const CartItem(id: 'p2', name: '三明治', price: 35, quantity: 2),
    ];
  }

  void addItem(String name, double price) {
    final existing = state.where((item) => item.name == name).firstOrNull;
    if (existing != null) {
      _updateQuantity(existing.id, existing.quantity + 1);
      return;
    }
    final item = CartItem(id: DateTime.now().millisecondsSinceEpoch.toString(), name: name, price: price);
    state = [...state, item];
  }

  void increment(String id) {
    _updateQuantity(id, _findItem(id).quantity + 1);
  }

  void decrement(String id) {
    final item = _findItem(id);
    if (item.quantity <= 1) {
      remove(id);
      return;
    }
    _updateQuantity(id, item.quantity - 1);
  }

  void remove(String id) {
    state = state.where((item) => item.id != id).toList();
  }

  void clear() {
    state = [];
  }

  void _updateQuantity(String id, int quantity) {
    state = [
      for (final item in state)
        if (item.id == id) item.copyWith(quantity: quantity) else item,
    ];
  }

  CartItem _findItem(String id) {
    return state.firstWhere((item) => item.id == id);
  }
}

/// 购物车 Provider
final cartProvider =
    NotifierProvider<CartNotifier, List<CartItem>>(CartNotifier.new);

/// 购物车总数量（派生 Provider）
final cartItemCountProvider = Provider<int>((ref) {
  final items = ref.watch(cartProvider);
  return items.fold(0, (sum, item) => sum + item.quantity);
});

/// 购物车总价（派生 Provider）
final cartTotalPriceProvider = Provider<double>((ref) {
  final items = ref.watch(cartProvider);
  return items.fold(0.0, (sum, item) => sum + item.price * item.quantity);
});
