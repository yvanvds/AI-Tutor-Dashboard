import 'package:flutter/material.dart';

class ChipsEditor extends StatefulWidget {
  const ChipsEditor({
    super.key,
    required this.values,
    required this.label,
    required this.onChanged,
    this.hintText,
  });

  final List<String> values;
  final String label;
  final ValueChanged<List<String>> onChanged;
  final String? hintText;

  @override
  State<ChipsEditor> createState() => _ChipsEditorState();
}

class _ChipsEditorState extends State<ChipsEditor> {
  late List<String> _items;
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _items = [...widget.values];
  }

  @override
  void didUpdateWidget(covariant ChipsEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // refresh local view if parent updates (e.g., from Firestore)
    if (oldWidget.values != widget.values) {
      _items = [...widget.values];
    }
  }

  void _add(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return;
    if (_items.contains(t)) return;
    setState(() => _items.add(t));
    widget.onChanged(_items);
    _ctrl.clear();
  }

  void _remove(String val) {
    setState(() => _items.remove(val));
    widget.onChanged(_items);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InputDecorator(
          decoration: InputDecoration(
            labelText: widget.label,
            border: const OutlineInputBorder(),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: -8,
            children: [
              for (final v in _items)
                InputChip(label: Text(v), onDeleted: () => _remove(v)),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 120, maxWidth: 240),
                child: TextField(
                  controller: _ctrl,
                  onSubmitted: _add,
                  decoration: InputDecoration(
                    hintText: widget.hintText ?? 'Add & press Enter',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
