import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/product.dart';

/// 购物车 Cubit（MVVM 中的 ViewModel 层）
///
/// 配合演示 [RepositoryProvider]（依赖注入）与
/// `MultiBlocProvider` / `BlocProvider.value`（跨子树共享同一个实例）。
///
/// 状态设计要点：
/// - 存「商品 × 数量」的行项目列表，而不是展开的重复商品；
/// - 总价、总件数都是 getter 派生值，绝不单独存字段，
///   避免两个数据源不一致（单一数据源原则）。
class CartCubit extends Cubit<CartState> {
  CartCubit() : super(const CartState());

  /// 加购：已有该商品则数量 +1，否则新增一行
  void add(Product product) {
    final items = [...state.items];
    final index = items.indexWhere((e) => e.product.id == product.id);
    if (index >= 0) {
      // 只替换受影响的那一行，其余行原样保留（不可变更新）
      items[index] = CartLineItem(
        product: product,
        quantity: items[index].quantity + 1,
      );
    } else {
      items.add(CartLineItem(product: product, quantity: 1));
    }
    emit(CartState(items: items));
  }

  /// 移除一件：数量 -1，减到 0 时移除整行
  void removeOne(int productId) {
    final items = [...state.items];
    final index = items.indexWhere((e) => e.product.id == productId);
    if (index < 0) return;

    final line = items[index];
    if (line.quantity <= 1) {
      items.removeAt(index);
    } else {
      items[index] = CartLineItem(
        product: line.product,
        quantity: line.quantity - 1,
      );
    }
    emit(CartState(items: items));
  }

  /// 清空购物车
  void clear() => emit(const CartState());
}

/// 购物车行项目：某商品 × 数量
///
/// 注意：行项目也要继承 [Equatable]，否则列表比较时
/// 行判等失效，BlocBuilder 的状态去重会失灵。
class CartLineItem extends Equatable {
  const CartLineItem({required this.product, required this.quantity});

  final Product product;
  final int quantity;

  /// 小计 = 单价 × 数量
  double get subtotal => product.price * quantity;

  @override
  List<Object?> get props => [product, quantity];
}

class CartState extends Equatable {
  const CartState({this.items = const []});

  final List<CartLineItem> items;

  /// 派生值：总件数
  int get totalCount => items.fold(0, (sum, e) => sum + e.quantity);

  /// 派生值：总价（所有行小计之和）
  double get totalPrice => items.fold(0, (sum, e) => sum + e.subtotal);

  bool get isEmpty => items.isEmpty;

  @override
  List<Object?> get props => [items];
}
