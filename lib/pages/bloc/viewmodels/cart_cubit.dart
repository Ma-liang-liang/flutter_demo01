import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// 购物车 Cubit（MVVM 中的 ViewModel 层）
///
/// 配合演示 [RepositoryProvider]（依赖注入）与
/// `MultiBlocProvider` / `BlocProvider.value`（跨子树共享同一个实例）。
class CartCubit extends Cubit<CartState> {
  CartCubit() : super(const CartState());

  void add(String itemName) {
    emit(
      state.copyWith(
        itemCount: state.itemCount + 1,
        lastAction: '已添加：$itemName',
      ),
    );
  }

  void remove() {
    if (state.itemCount == 0) return;
    emit(state.copyWith(itemCount: state.itemCount - 1, lastAction: '已移除 1 件商品'));
  }

  void clear() => emit(const CartState(lastAction: '购物车已清空'));
}

class CartState extends Equatable {
  const CartState({this.itemCount = 0, this.lastAction = ''});

  final int itemCount;
  final String lastAction;

  double get totalPrice => itemCount * 19.9;

  CartState copyWith({int? itemCount, String? lastAction}) => CartState(
    itemCount: itemCount ?? this.itemCount,
    lastAction: lastAction ?? this.lastAction,
  );

  @override
  List<Object?> get props => [itemCount, lastAction];
}
