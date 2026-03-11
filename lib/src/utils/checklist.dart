import 'dart:io';

/// Renders an interactive toggle checklist in the terminal.
/// Returns a Set of the selected item labels.
class Checklist {
  Checklist._();

  static Set<String> prompt({
    required String title,
    required List<ChecklistItem> items,
  }) {
    // Default all to their initial value
    final selected = {
      for (final item in items)
        if (item.defaultOn) item.label,
    };

    stdin.echoMode = false;
    stdin.lineMode = false;

    int cursor = 0;

    void render() {
      // Move cursor up to overwrite previous render (skip on first draw)
      stdout.write('\x1B[${items.length + 2}A');
      stdout.write('\r');

      stdout.writeln('\n$title');
      for (int i = 0; i < items.length; i++) {
        final isOn = selected.contains(items[i].label);
        final isCursor = i == cursor;
        final checkbox = isOn ? '[✓]' : '[ ]';
        final pointer = isCursor ? '▶ ' : '  ';
        final label = isCursor ? '\x1B[1m${items[i].label}\x1B[0m' : items[i].label;
        stdout.writeln('$pointer$checkbox  $label');
      }
    }

    // First draw — just print, no overwrite
    stdout.writeln('\n$title');
    for (int i = 0; i < items.length; i++) {
      final isOn = selected.contains(items[i].label);
      final isCursor = i == cursor;
      final checkbox = isOn ? '[✓]' : '[ ]';
      final pointer = isCursor ? '▶ ' : '  ';
      final label = isCursor ? '\x1B[1m${items[i].label}\x1B[0m' : items[i].label;
      stdout.writeln('$pointer$checkbox  $label');
    }

    stdout.writeln('  ↑/↓ navigate  •  space toggle  •  enter confirm');

    bool done = false;
    while (!done) {
      final byte = stdin.readByteSync();

      if (byte == 27) {
        // ESC sequence
        final b2 = stdin.readByteSync();
        if (b2 == 91) {
          final b3 = stdin.readByteSync();
          if (b3 == 65 && cursor > 0) cursor--; // up
          if (b3 == 66 && cursor < items.length - 1) cursor++; // down
        }
      } else if (byte == 32) {
        // space — toggle
        final label = items[cursor].label;
        if (selected.contains(label)) {
          selected.remove(label);
        } else {
          selected.add(label);
        }
      } else if (byte == 10 || byte == 13) {
        // enter
        done = true;
      }

      if (!done) render();
    }

    stdin.echoMode = true;
    stdin.lineMode = true;

    stdout.writeln('');
    return selected;
  }
}

class ChecklistItem {
  const ChecklistItem(this.label, {this.defaultOn = true});
  final String label;
  final bool defaultOn;
}
