import 'package:equatable/equatable.dart';

/// 商品实体（MVVM 中的 Model 层 · 实体）
///
/// 不同商品价格不同，价格作为商品自身的属性存在，
/// 购物车行项目只引用商品，不单独存价格副本。
class Product extends Equatable {
  const Product({
    required this.id,
    required this.name,
    required this.emoji,
    required this.price,
  });

  final int id;
  final String name;
  final String emoji;
  final double price;

  @override
  List<Object?> get props => [id, name, emoji, price];
}

/// 演示用商品列表（价格各不相同）
const sampleProducts = <Product>[
  Product(id: 1, name: 'Flutter 实战指南', emoji: '📘', price: 68.0),
  Product(id: 2, name: '状态管理徽章', emoji: '🏅', price: 19.9),
  Product(id: 3, name: 'Dart 语言精粹', emoji: '📗', price: 45.5),
];
