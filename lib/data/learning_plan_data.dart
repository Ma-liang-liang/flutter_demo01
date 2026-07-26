import 'package:flutter/material.dart';

import '../models/learning_topic.dart';
import '../pages/learn/demos/animation/explicit_anim_demo.dart';
import '../pages/learn/demos/animation/gesture_demo.dart';
import '../pages/learn/demos/animation/implicit_anim_demo.dart';
import '../pages/learn/demos/basic/button_deep_demo.dart';
import '../pages/learn/demos/basic/dialog_demo.dart';
import '../pages/learn/demos/basic/image_icon_demo.dart';
import '../pages/learn/demos/basic/text_deep_demo.dart';
import '../pages/learn/demos/form/date_picker_demo.dart';
import '../pages/learn/demos/form/selector_demo.dart';
import '../pages/learn/demos/form/text_field_demo.dart';
import '../pages/learn/demos/layout/list_grid_demo.dart';
import '../pages/learn/demos/layout/row_column_demo.dart';
import '../pages/learn/demos/layout/stack_demo.dart';

/// 学习计划数据
///
/// 集中维护 4 个章节（对应 4 个主 Tab 分类）的学习主题列表。
/// 新增演示页时，在对应章节的 topics 中追加一项即可。
class LearningPlanData {
  LearningPlanData._();

  /// 全部学习章节
  static const chapters = <LearningChapter>[
    basicChapter,
    formChapter,
    layoutChapter,
    animationChapter,
  ];

  /// 基础组件章节
  static const basicChapter = LearningChapter(
    id: 'basic',
    title: '基础组件学习计划',
    goal: '从最常用的文本、按钮、图片到弹窗体系，掌握 Flutter 界面的基础构成单元。',
    topics: [
      LearningTopic(
        title: '文本深入',
        subtitle: '样式定制 / 溢出处理 / 富文本 / 可选中文本',
        icon: Icons.text_fields_outlined,
        demoPage: TextDeepDemo(),
      ),
      LearningTopic(
        title: '按钮深入',
        subtitle: '样式定制 / 禁用与加载态 / 按钮组',
        icon: Icons.smart_button_outlined,
        demoPage: ButtonDeepDemo(),
      ),
      LearningTopic(
        title: '图片与图标',
        subtitle: '形状裁剪 / BoxFit / 网络图兜底 / 图标定制',
        icon: Icons.image_outlined,
        demoPage: ImageIconDemo(),
      ),
      LearningTopic(
        title: '弹窗体系',
        subtitle: 'AlertDialog / SimpleDialog / BottomSheet / SnackBar',
        icon: Icons.open_in_new_outlined,
        demoPage: DialogDemo(),
      ),
    ],
  );

  /// 表单组件章节
  static const formChapter = LearningChapter(
    id: 'form',
    title: '表单组件学习计划',
    goal: '掌握用户输入的收集与处理：输入框控制、各类选择器与系统日期时间弹窗。',
    topics: [
      LearningTopic(
        title: '输入框深入',
        subtitle: '装饰定制 / 控制器 / 焦点跳转 / 键盘配置',
        icon: Icons.edit_outlined,
        demoPage: TextFieldDemo(),
      ),
      LearningTopic(
        title: '选择器深入',
        subtitle: '单选 / 多选 / 开关 / 滑块 / 下拉框',
        icon: Icons.check_circle_outline,
        demoPage: SelectorDemo(),
      ),
      LearningTopic(
        title: '日期时间选择器',
        subtitle: 'showDatePicker / showTimePicker / 日期范围',
        icon: Icons.event_outlined,
        demoPage: DatePickerDemo(),
      ),
    ],
  );

  /// 布局组件章节
  static const layoutChapter = LearningChapter(
    id: 'layout',
    title: '布局组件学习计划',
    goal: '理解 Flutter 布局的核心思想：约束传递、主轴对齐、层叠定位与滚动容器。',
    topics: [
      LearningTopic(
        title: '行列布局深入',
        subtitle: '主轴 / 交叉轴对齐 / Expanded 比例分配',
        icon: Icons.view_column_outlined,
        demoPage: RowColumnDemo(),
      ),
      LearningTopic(
        title: '层叠定位',
        subtitle: 'Stack / Positioned / 角标与遮罩实战',
        icon: Icons.layers_outlined,
        demoPage: StackDemo(),
      ),
      LearningTopic(
        title: '列表与网格',
        subtitle: 'ListView 懒加载 / 分隔列表 / GridView',
        icon: Icons.grid_view_outlined,
        demoPage: ListGridDemo(),
      ),
    ],
  );

  /// 动画交互章节
  static const animationChapter = LearningChapter(
    id: 'animation',
    title: '动画交互学习计划',
    goal: '从简单的隐式动画到手动的显式动画，再到丰富的手势交互，让界面生动起来。',
    topics: [
      LearningTopic(
        title: '隐式动画',
        subtitle: 'AnimatedContainer / Opacity / Align / TextStyle',
        icon: Icons.animation_outlined,
        demoPage: ImplicitAnimDemo(),
      ),
      LearningTopic(
        title: '显式动画',
        subtitle: 'AnimationController / 缓动曲线 / 组合动画',
        icon: Icons.play_circle_outline,
        demoPage: ExplicitAnimDemo(),
      ),
      LearningTopic(
        title: '手势交互',
        subtitle: '点击长按 / 拖拽 / 水波纹 / 拖放',
        icon: Icons.touch_app_outlined,
        demoPage: GestureDemo(),
      ),
    ],
  );

  /// 按章节 id 查找章节
  static LearningChapter byId(String id) {
    return chapters.firstWhere((chapter) => chapter.id == id);
  }
}
