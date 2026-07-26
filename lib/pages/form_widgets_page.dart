import 'package:flutter/material.dart';

import '../data/learning_plan_data.dart';
import '../widgets/learning_entry_card.dart';
import '../widgets/section_card.dart';

/// Tab2: 表单组件展示页面
///
/// 展示常用的表单组件：TextField、Switch、Checkbox、Slider、
/// Radio、DropdownButton、SegmentedButton 等。
class FormWidgetsPage extends StatefulWidget {
  const FormWidgetsPage({super.key});

  @override
  State<FormWidgetsPage> createState() => _FormWidgetsPageState();
}

class _FormWidgetsPageState extends State<FormWidgetsPage> {
  // --- 输入框 ---
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // --- 开关 / 复选框 / 单选框 ---
  bool _switchValue = true;
  bool _checkboxValue = false;
  int _radioValue = 0;

  // --- 滑块 ---
  double _sliderValue = 50;
  double _rangeStart = 20;
  double _rangeEnd = 80;

  // --- 下拉框 ---
  String? _dropdownValue;
  final List<String> _dropdownItems = ['选项 A', '选项 B', '选项 C', '选项 D'];

  // --- SegmentedButton ---
  int _segmentValue = 0;

  @override
  void dispose() {
    _textController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 学习计划入口：点击进入本分类的章节列表（二级页面）
        const LearningEntryCard(chapter: LearningPlanData.formChapter),
        _TextFieldSection(
          textController: _textController,
          passwordController: _passwordController,
          onChanged: (v) => _showSnackBar('输入: $v'),
        ),
        _SwitchSection(
          switchValue: _switchValue,
          checkboxValue: _checkboxValue,
          radioValue: _radioValue,
          onSwitchChanged: (v) => setState(() => _switchValue = v),
          onCheckboxChanged: (v) => setState(() => _checkboxValue = v),
          onRadioChanged: (v) => setState(() => _radioValue = v),
        ),
        _SliderSection(
          sliderValue: _sliderValue,
          rangeStart: _rangeStart,
          rangeEnd: _rangeEnd,
          onSliderChanged: (v) => setState(() => _sliderValue = v),
          onRangeChanged: (values) => setState(() {
            _rangeStart = values.start;
            _rangeEnd = values.end;
          }),
        ),
        _SelectionSection(
          dropdownValue: _dropdownValue,
          dropdownItems: _dropdownItems,
          segmentValue: _segmentValue,
          onDropdownChanged: (v) => setState(() => _dropdownValue = v),
          onSegmentChanged: (v) => setState(() => _segmentValue = v),
        ),
        _DatePickerSection(onPicked: (date) => _showSnackBar('选择了: $date')),
        const _FormValidationSection(),
        _SearchBarSection(onSearch: (v) => _showSnackBar('搜索: $v')),
        _AutocompleteSection(onSelected: (v) => _showSnackBar('选择了: $v')),
      ],
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
          SnackBar(content: Text(message), duration: const Duration(seconds: 1)));
  }
}

// ---------------------------------------------------------------------------
// 输入框区域
// ---------------------------------------------------------------------------
class _TextFieldSection extends StatelessWidget {
  const _TextFieldSection({
    required this.textController,
    required this.passwordController,
    required this.onChanged,
  });

  final TextEditingController textController;
  final TextEditingController passwordController;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '输入框',
      subtitle: 'TextField / 密码框 / 多行输入',
      icon: Icons.edit,
      child: Column(
        children: [
          TextField(
            controller: textController,
            decoration: const InputDecoration(
              labelText: '用户名',
              hintText: '请输入用户名',
              prefixIcon: Icon(Icons.person_outline),
            ),
            onChanged: onChanged,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: '密码',
              hintText: '请输入密码',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 12),
          const TextField(
            maxLines: 3,
            decoration: InputDecoration(
              labelText: '多行输入',
              hintText: '请输入多行文本...',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 开关 / 复选框 / 单选框区域
// ---------------------------------------------------------------------------
class _SwitchSection extends StatelessWidget {
  const _SwitchSection({
    required this.switchValue,
    required this.checkboxValue,
    required this.radioValue,
    required this.onSwitchChanged,
    required this.onCheckboxChanged,
    required this.onRadioChanged,
  });

  final bool switchValue;
  final bool checkboxValue;
  final int radioValue;
  final ValueChanged<bool> onSwitchChanged;
  final ValueChanged<bool> onCheckboxChanged;
  final ValueChanged<int> onRadioChanged;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '开关 / 复选 / 单选',
      subtitle: 'Switch / Checkbox / Radio',
      icon: Icons.toggle_on,
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('通知开关'),
            subtitle: const Text('接收推送通知'),
            value: switchValue,
            onChanged: onSwitchChanged,
          ),
          CheckboxListTile(
            title: const Text('同意条款'),
            value: checkboxValue,
            onChanged: (v) => onCheckboxChanged(v ?? false),
          ),
          const Divider(),
          RadioGroup<int>(
            groupValue: radioValue,
            onChanged: (v) => onRadioChanged(v ?? 0),
            child: Column(
              children: [
                const RadioListTile<int>(
                  title: Text('选项一'),
                  value: 0,
                ),
                const RadioListTile<int>(
                  title: Text('选项二'),
                  value: 1,
                ),
                const RadioListTile<int>(
                  title: Text('选项三'),
                  value: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 滑块区域
// ---------------------------------------------------------------------------
class _SliderSection extends StatelessWidget {
  const _SliderSection({
    required this.sliderValue,
    required this.rangeStart,
    required this.rangeEnd,
    required this.onSliderChanged,
    required this.onRangeChanged,
  });

  final double sliderValue;
  final double rangeStart;
  final double rangeEnd;
  final ValueChanged<double> onSliderChanged;
  final ValueChanged<RangeValues> onRangeChanged;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '滑块',
      subtitle: 'Slider / RangeSlider',
      icon: Icons.linear_scale,
      child: Column(
        children: [
          Text('当前值: ${sliderValue.round()}'),
          Slider(
            value: sliderValue,
            min: 0,
            max: 100,
            divisions: 10,
            label: sliderValue.round().toString(),
            onChanged: onSliderChanged,
          ),
          const SizedBox(height: 8),
          Text('范围: ${rangeStart.round()} ~ ${rangeEnd.round()}'),
          RangeSlider(
            values: RangeValues(rangeStart, rangeEnd),
            min: 0,
            max: 100,
            divisions: 10,
            labels: RangeLabels(
              rangeStart.round().toString(),
              rangeEnd.round().toString(),
            ),
            onChanged: onRangeChanged,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 下拉框 / SegmentedButton 区域
// ---------------------------------------------------------------------------
class _SelectionSection extends StatelessWidget {
  const _SelectionSection({
    required this.dropdownValue,
    required this.dropdownItems,
    required this.segmentValue,
    required this.onDropdownChanged,
    required this.onSegmentChanged,
  });

  final String? dropdownValue;
  final List<String> dropdownItems;
  final int segmentValue;
  final ValueChanged<String?> onDropdownChanged;
  final ValueChanged<int> onSegmentChanged;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '选择器',
      subtitle: 'DropdownButton / SegmentedButton',
      icon: Icons.arrow_drop_down_circle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: dropdownValue,
            decoration: const InputDecoration(
              labelText: '请选择',
            ),
            items: dropdownItems
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: onDropdownChanged,
          ),
          const SizedBox(height: 16),
          const Text('SegmentedButton'),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('日'), icon: Icon(Icons.today)),
              ButtonSegment(value: 1, label: Text('周'), icon: Icon(Icons.date_range)),
              ButtonSegment(value: 2, label: Text('月'), icon: Icon(Icons.calendar_month)),
            ],
            selected: {segmentValue},
            onSelectionChanged: (set) => onSegmentChanged(set.first),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 日期选择器区域
// ---------------------------------------------------------------------------
class _DatePickerSection extends StatelessWidget {
  const _DatePickerSection({required this.onPicked});

  final ValueChanged<String> onPicked;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '日期 / 时间选择器',
      subtitle: 'showDatePicker / showTimePicker',
      icon: Icons.calendar_today,
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.calendar_month),
              label: const Text('选择日期'),
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (date != null) {
                  onPicked('${date.year}-${date.month}-${date.day}');
                }
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.access_time),
              label: const Text('选择时间'),
              onPressed: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (time != null) {
                  onPicked('${time.hour}:${time.minute}');
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Form 表单验证区域
// ---------------------------------------------------------------------------

/// 演示 Form + `GlobalKey<FormState>` 实现表单校验：
/// - validator 返回 null 表示通过，返回字符串则显示为错误提示
/// - _formKey.currentState!.validate() 触发所有字段校验
/// - save() 会调用每个字段的 onSaved 回调
class _FormValidationSection extends StatefulWidget {
  const _FormValidationSection();

  @override
  State<_FormValidationSection> createState() => _FormValidationSectionState();
}

class _FormValidationSectionState extends State<_FormValidationSection> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Form 表单验证',
      subtitle: 'TextFormField / validator / validate() / reset()',
      icon: Icons.verified_user,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: '用户名 *',
                hintText: '4~12 个字符',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return '用户名不能为空';
                if (value.trim().length < 4) return '用户名至少 4 个字符';
                if (value.trim().length > 12) return '用户名最多 12 个字符';
                return null; // 返回 null 表示校验通过
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: '邮箱 *',
                hintText: 'example@mail.com',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return '邮箱不能为空';
                // 简单的邮箱正则校验
                final emailRegex = RegExp(r'^[\w.-]+@[\w-]+(\.[\w-]+)+$');
                if (!emailRegex.hasMatch(value)) return '请输入有效的邮箱地址';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '密码 *',
                hintText: '至少 6 位',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              validator: (value) {
                if (value == null || value.length < 6) return '密码至少 6 位';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '确认密码 *',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              validator: (value) {
                if (value != _passwordController.text) return '两次输入的密码不一致';
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text('提交'),
                    onPressed: () {
                      // validate() 返回 true 表示所有字段校验通过
                      if (_formKey.currentState!.validate()) {
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(
                              content: Text('注册成功，欢迎 ${_usernameController.text}!'),
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                            ),
                          );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('重置'),
                    onPressed: () {
                      // reset() 清空所有字段并移除错误提示
                      _formKey.currentState!.reset();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SearchBar 区域
// ---------------------------------------------------------------------------

/// 演示 Material 3 的 SearchBar 组件：
/// - 支持 leading / trailing / hintText 等装饰
/// - 可通过 elevation 和 shape 自定义外观
class _SearchBarSection extends StatelessWidget {
  const _SearchBarSection({required this.onSearch});

  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'SearchBar',
      subtitle: 'Material 3 搜索栏',
      icon: Icons.search,
      child: Column(
        children: [
          SearchBar(
            hintText: '搜索组件...',
            leading: const Icon(Icons.search),
            trailing: [
              IconButton(
                icon: const Icon(Icons.mic),
                onPressed: () => onSearch('语音搜索'),
              ),
            ],
            onSubmitted: onSearch,
          ),
          const SizedBox(height: 12),
          SearchBar(
            hintText: '带 elevation 的搜索栏',
            leading: const Icon(Icons.travel_explore),
            elevation: const WidgetStatePropertyAll(4),
            onSubmitted: onSearch,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Autocomplete 区域
// ---------------------------------------------------------------------------

/// 演示 Autocomplete 自动补全组件：
/// - optionsBuilder 根据用户输入过滤候选项
/// - onSelected 在用户选中某项时回调
class _AutocompleteSection extends StatelessWidget {
  const _AutocompleteSection({required this.onSelected});

  final ValueChanged<String> onSelected;

  static const _cities = [
    '北京', '上海', '广州', '深圳', '杭州',
    '成都', '武汉', '南京', '重庆', '西安',
    '苏州', '天津',
  ];

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Autocomplete',
      subtitle: '自动补全输入',
      icon: Icons.lightbulb_outline,
      child: Autocomplete<String>(
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) return const Iterable.empty();
          return _cities.where((city) => city.contains(textEditingValue.text));
        },
        onSelected: onSelected,
        fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
          return TextField(
            controller: controller,
            focusNode: focusNode,
            decoration: const InputDecoration(
              labelText: '输入城市名',
              hintText: '试试输入 "北" 或 "上"',
              prefixIcon: Icon(Icons.location_city),
            ),
            onSubmitted: (_) => onSubmitted(),
          );
        },
      ),
    );
  }
}
