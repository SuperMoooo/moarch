import 'dart:io';

/// Cross-platform checklist prompt.
/// Shows numbered items — user types numbers to toggle, then presses enter to confirm.
/// Works on Windows, macOS, and Linux without raw terminal mode.
class Checklist {
  Checklist._();

  static Set<String> prompt({
    required String title,
    required List<ChecklistItem> items,
  }) {
    final selected = {
      for (final item in items)
        if (item.defaultOn) item.label,
    };

    while (true) {
      _render(title, items, selected);

      stdout.write('  Toggle (1-${items.length}) or press enter to confirm: ');
      final input = stdin.readLineSync()?.trim() ?? '';

      // Empty input = confirm
      if (input.isEmpty) break;

      // Accept comma-separated or space-separated numbers e.g. "1 3" or "2,4"
      final parts = input.split(RegExp(r'[\s,]+'));
      for (final part in parts) {
        final n = int.tryParse(part);
        if (n != null && n >= 1 && n <= items.length) {
          final label = items[n - 1].label;
          if (selected.contains(label)) {
            selected.remove(label);
          } else {
            selected.add(label);
          }
        }
      }
    }

    stdout.writeln('');
    return selected;
  }

  static void _render(
    String title,
    List<ChecklistItem> items,
    Set<String> selected,
  ) {
    stdout.writeln('');
    stdout.writeln('  $title');
    stdout.writeln('');
    for (int i = 0; i < items.length; i++) {
      final isOn = selected.contains(items[i].label);
      final checkbox = isOn ? '[✓]' : '[ ]';
      final n = '${i + 1}'.padLeft(2);
      stdout.writeln('  $n)  $checkbox  ${items[i].label}');
    }
    stdout.writeln('');
    stdout.writeln('  Type a number to toggle. Press enter to confirm.');
  }
}

class ChecklistItem {
  const ChecklistItem(this.label, {this.defaultOn = true});
  final String label;
  final bool defaultOn;
}
