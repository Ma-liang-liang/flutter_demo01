import 'package:flutter/material.dart';

import '../../../../widgets/demo_page_scaffold.dart';
import '../../../../widgets/section_card.dart';

/// 学习计划 · 表单组件 · 日期时间选择器
///
/// 演示 showDatePicker、showTimePicker、showDateRangePicker 系统选择弹窗。
class DatePickerDemo extends StatefulWidget {
  const DatePickerDemo({super.key});

  @override
  State<DatePickerDemo> createState() => _DatePickerDemoState();
}

class _DatePickerDemoState extends State<DatePickerDemo> {
  DateTime? _date;
  TimeOfDay? _time;
  DateTimeRange? _range;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      // 中文文案需在 main.dart 配置本地化，此处默认英文界面
      helpText: '选择日期',
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _range,
    );
    if (picked != null) setState(() => _range = picked);
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return DemoPageScaffold(
      title: '日期时间选择器',
      goal: '学会调用系统日期、时间与日期范围选择弹窗，并处理用户取消与确认两种返回结果。',
      children: [
        _PickerSection(
          icon: Icons.calendar_month_outlined,
          title: '日期选择 showDatePicker',
          subtitle: '生日、预约日期等单日选择场景',
          result: _date == null ? '未选择' : _formatDate(_date!),
          onTap: _pickDate,
        ),
        _PickerSection(
          icon: Icons.schedule_outlined,
          title: '时间选择 showTimePicker',
          subtitle: '闹钟、提醒时间等时刻选择场景',
          result: _time == null ? '未选择' : _time!.format(context),
          onTap: _pickTime,
        ),
        _PickerSection(
          icon: Icons.date_range_outlined,
          title: '日期范围 showDateRangePicker',
          subtitle: '酒店入住、报表筛选等区间选择场景',
          result: _range == null
              ? '未选择'
              : '${_formatDate(_range!.start)}  ~  ${_formatDate(_range!.end)}',
          onTap: _pickRange,
        ),
        SectionCard(
          title: '知识要点',
          subtitle: '三个 API 的共同模式',
          icon: Icons.lightbulb_outline,
          child: const Text(
            '1. 都是返回 Future 的异步函数，用 await 等待结果\n'
            '2. 用户点击「取消」时返回 null，必须做空值判断\n'
            '3. 用 setState 保存结果并刷新界面显示',
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 选择器行：图标 + 说明 + 结果 + 触发按钮
// ---------------------------------------------------------------------------
class _PickerSection extends StatelessWidget {
  const _PickerSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.result,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: title,
      subtitle: subtitle,
      icon: icon,
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                result,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.tonal(onPressed: onTap, child: const Text('选择')),
        ],
      ),
    );
  }
}
