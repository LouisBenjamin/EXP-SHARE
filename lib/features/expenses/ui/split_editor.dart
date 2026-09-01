import 'package:decimal/decimal.dart';
import 'package:exp_share/core/money.dart';
import 'package:exp_share/models/group_member.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Presentational widgets shared by the add-expense and add-recurring forms.
// The split *maths* lives in split_logic.dart; these just render the controls.

// Equal / Exact / % selector.
class SplitTypeSelector extends StatelessWidget {
  const SplitTypeSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'equal', label: Text('Equally')),
        ButtonSegment(value: 'exact', label: Text('Exact')),
        ButtonSegment(value: 'percent', label: Text('%')),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

// One participant row: a checkbox plus, when included, the equal share (read
// only) or an exact / percent entry field.
class ParticipantSplitRow extends StatelessWidget {
  const ParticipantSplitRow({
    super.key,
    required this.member,
    required this.included,
    required this.splitType,
    required this.equalShare,
    required this.exactController,
    required this.percentController,
    required this.onToggle,
    required this.onChanged,
  });

  final GroupMember member;
  final bool included;
  final String splitType;
  final Decimal? equalShare;
  final TextEditingController exactController;
  final TextEditingController percentController;
  final ValueChanged<bool> onToggle;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    Widget? trailing;
    if (included) {
      switch (splitType) {
        case 'exact':
          trailing = MiniAmountField(
            controller: exactController,
            prefix: r'$',
            onChanged: onChanged,
          );
        case 'percent':
          trailing = MiniAmountField(
            controller: percentController,
            suffix: '%',
            onChanged: onChanged,
          );
        default:
          trailing = Text(
            equalShare != null ? formatCurrency(equalShare!) : '',
            style: Theme.of(context).textTheme.bodyMedium,
          );
      }
    }

    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: included,
      onChanged: (v) => onToggle(v ?? false),
      title: Text(member.displayName),
      secondary: trailing,
    );
  }
}

// Narrow numeric field (max two decimals) used for exact amounts and percents.
class MiniAmountField extends StatelessWidget {
  const MiniAmountField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.prefix,
    this.suffix,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;
  final String? prefix;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90,
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.end,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
        ],
        onChanged: (_) => onChanged(),
        decoration: InputDecoration(
          isDense: true,
          prefixText: prefix,
          suffixText: suffix,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
