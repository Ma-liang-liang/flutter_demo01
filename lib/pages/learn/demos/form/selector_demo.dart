import 'package:flutter/material.dart';

import '../../../../widgets/demo_page_scaffold.dart';
import '../../../../widgets/section_card.dart';

/// 学习计划 · 表单组件 · 选择器深入
///
/// 演示 RadioGroup 单选、Checkbox 多选、Switch 开关、Slider 滑块与下拉选择框。
class SelectorDemo extends StatefulWidget {
  const SelectorDemo({super.key});

  @override
  State<SelectorDemo> createState() => _SelectorDemoState();
}

class _SelectorDemoState extends State<SelectorDemo> {
  int _radioValue = 0;
  bool _check1 = true;
  bool _check2 = false;
  bool? _triState;
  bool _switchOn = true;
  double _sliderValue = 40;
  RangeValues _rangeValues = const RangeValues(20, 80);
  String _dropdownValue = '苹果';

  @override
  Widget build(BuildContext context) {
    return DemoPageScaffold(
      title: '选择器深入',
      goal: '掌握单选、多选、开关、滑块和下拉框五大选择类组件的用法与状态管理，理解受控组件的更新模式。',
      children: [
        _RadioSection(
          groupValue: _radioValue,
          onChanged: (v) => setState(() => _radioValue = v ?? 0),
        ),
        _CheckboxSection(
          check1: _check1,
          check2: _check2,
          triState: _triState,
          onCheck1: (v) => setState(() => _check1 = v ?? false),
          onCheck2: (v) => setState(() => _check2 = v ?? false),
          onTriState: (v) => setState(() => _triState = v),
        ),
        _SwitchSection(
          value: _switchOn,
          onChanged: (v) => setState(() => _switchOn = v),
        ),
        _SliderSection(
          value: _sliderValue,
          range: _rangeValues,
          onValue: (v) => setState(() => _sliderValue = v),
          onRange: (v) => setState(() => _rangeValues = v),
        ),
        _DropdownSection(
          value: _dropdownValue,
          onChanged: (v) => setState(() => _dropdownValue = v ?? _dropdownValue),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Radio 单选
// ---------------------------------------------------------------------------
class _RadioSection extends StatelessWidget {
  const _RadioSection({required this.groupValue, required this.onChanged});

  final int groupValue;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Radio 单选',
      subtitle: 'RadioGroup 统一管理选中值（Flutter 3.47+ 写法）',
      icon: Icons.radio_button_checked_outlined,
      // RadioGroup 包裹一组 Radio，无需为每个 Radio 单独传 groupValue
      child: RadioGroup<int>(
        groupValue: groupValue,
        onChanged: onChanged,
        child: const Column(
          children: [
            RadioListTile<int>(value: 0, title: Text('标准配送（免运费）')),
            RadioListTile<int>(value: 1, title: Text('加急配送（+8元）')),
            RadioListTile<int>(value: 2, title: Text('门店自提')),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Checkbox 多选
// ---------------------------------------------------------------------------
class _CheckboxSection extends StatelessWidget {
  const _CheckboxSection({
    required this.check1,
    required this.check2,
    required this.triState,
    required this.onCheck1,
    required this.onCheck2,
    required this.onTriState,
  });

  final bool check1;
  final bool check2;
  final bool? triState;
  final ValueChanged<bool?> onCheck1;
  final ValueChanged<bool?> onCheck2;
  final ValueChanged<bool?> onTriState;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Checkbox 多选',
      subtitle: 'tristate 支持「半选」第三态',
      icon: Icons.check_box_outlined,
      child: Column(
        children: [
          CheckboxListTile(
            value: check1,
            onChanged: onCheck1,
            title: const Text('接收订单通知'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          CheckboxListTile(
            value: check2,
            onChanged: onCheck2,
            title: const Text('接收营销推送'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          // 三态复选框：常用于「全选」场景
          CheckboxListTile(
            value: triState,
            tristate: true,
            onChanged: onTriState,
            title: Text(triState == null ? '半选状态（tristate）' : '当前：${triState! ? "全选" : "全不选"}'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Switch 开关
// ---------------------------------------------------------------------------
class _SwitchSection extends StatelessWidget {
  const _SwitchSection({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Switch 开关',
      subtitle: '适合即时生效的设置项',
      icon: Icons.toggle_on_outlined,
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        title: const Text('深色模式跟随系统'),
        subtitle: Text(value ? '已开启' : '已关闭'),
        secondary: Icon(value ? Icons.dark_mode : Icons.dark_mode_outlined),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Slider 滑块
// ---------------------------------------------------------------------------
class _SliderSection extends StatelessWidget {
  const _SliderSection({
    required this.value,
    required this.range,
    required this.onValue,
    required this.onRange,
  });

  final double value;
  final RangeValues range;
  final ValueChanged<double> onValue;
  final ValueChanged<RangeValues> onRange;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Slider 滑块',
      subtitle: '连续数值与区间范围选择',
      icon: Icons.tune_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('音量：${value.round()}'),
          Slider(
            value: value,
            max: 100,
            divisions: 10,
            label: value.round().toString(),
            onChanged: onValue,
          ),
          Text('价格区间：${range.start.round()} - ${range.end.round()} 元'),
          RangeSlider(
            values: range,
            max: 100,
            divisions: 10,
            labels: RangeLabels(range.start.round().toString(), range.end.round().toString()),
            onChanged: onRange,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dropdown 下拉选择
// ---------------------------------------------------------------------------
class _DropdownSection extends StatelessWidget {
  const _DropdownSection({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Dropdown 下拉选择',
      subtitle: 'DropdownButtonFormField 表单下拉框',
      icon: Icons.arrow_drop_down_circle_outlined,
      child: DropdownButtonFormField<String>(
        // Flutter 3.47+：value 参数已废弃，改用 initialValue
        initialValue: value,
        decoration: const InputDecoration(
          labelText: '喜欢的水果',
          border: OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem(value: '苹果', child: Text('苹果')),
          DropdownMenuItem(value: '香蕉', child: Text('香蕉')),
          DropdownMenuItem(value: '橙子', child: Text('橙子')),
          DropdownMenuItem(value: '西瓜', child: Text('西瓜')),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
