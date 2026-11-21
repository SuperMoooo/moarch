import 'dart:io';

/// Thrown when the user quits a [Checklist.prompt] instead of confirming.
class ChecklistCancelled implements Exception {
  /// Creates the cancellation signal.
  const ChecklistCancelled();
}

/// Cross-platform checklist prompt.
/// Shows numbered items — user types numbers to toggle, then presses enter to confirm.
/// Works on Windows, macOS, and Linux without raw terminal mode.
class Checklist {
  Checklist._();

  /// Shows [items] as a checklist and returns the labels left ticked.
  ///
  /// [preselected], when given, replaces each item's `defaultOn` as the
  /// starting selection. Labels in [locked] start ticked and cannot be
  /// unticked; [lockedReason] says why, next to each of them.
  ///
  /// Throws [ChecklistCancelled] if the user types `q` to quit.
  static Set<String> prompt({
    required String title,
    required List<ChecklistItem> items,
    Set<String>? preselected,
    Set<String> locked = const <String>{},
    String lockedReason = 'required',
  }) {
    final labels = {for (final item in items) item.label};
    final lockedHere = locked.intersection(labels);
    final selected = {
      ...?preselected?.intersection(labels),
      if (preselected == null)
        for (final item in items)
          if (item.defaultOn) item.label,
      ...lockedHere,
    };
    String? notice;

    while (true) {
      _render(title, items, selected, lockedHere, lockedReason);
      if (notice != null) {
        stdout.writeln('  $notice');
        notice = null;
      }

      stdout.write(
        '  Toggle (1-${items.length}), enter to confirm, q to quit: ',
      );
      final input = stdin.readLineSync()?.trim() ?? '';

      // Empty input = confirm
      if (input.isEmpty) break;

      if (input.toLowerCase() == 'q') {
        throw const ChecklistCancelled();
      }

      // Accept comma-separated or space-separated numbers e.g. "1 3" or "2,4"
      final parts = input.split(RegExp(r'[\s,]+'));
      for (final part in parts) {
        final n = int.tryParse(part);
        if (n != null && n >= 1 && n <= items.length) {
          final item = items[n - 1];
          final clashes = item.excludes.intersection(lockedHere);
          if (lockedHere.contains(item.label)) {
            notice = '"${item.label}" is $lockedReason.';
          } else if (clashes.isNotEmpty) {
            notice =
                '"${item.label}" cannot be combined with "${clashes.first}".';
          } else if (selected.contains(item.label)) {
            selected.remove(item.label);
          } else {
            selected.add(item.label);
            // Turning this item on deselects anything it excludes.
            selected.removeAll(item.excludes);
          }
        }
      }
    }

    stdout.writeln('');
    return selected;
  }

  /// Shows [items] as a numbered list and returns the index of the one
  /// picked. Enter alone picks [defaultIndex].
  ///
  /// Throws [ChecklistCancelled] if the user types `q` to quit.
  static int chooseOne({
    required String title,
    required List<ChecklistItem> items,
    int defaultIndex = 0,
  }) {
    while (true) {
      stdout.writeln('');
      stdout.writeln('  $title');
      stdout.writeln('');
      for (int i = 0; i < items.length; i++) {
        final marker = i == defaultIndex ? '(•)' : '( )';
        final n = '${i + 1}'.padLeft(2);
        stdout.writeln('  $n)  $marker  ${items[i].label}');
        if (items[i].description != null) {
          stdout.writeln('        ${items[i].description}');
        }
      }
      stdout.writeln('');
      stdout.write(
        '  Pick one (1-${items.length}), enter for ${defaultIndex + 1}, '
        'q to quit: ',
      );
      final input = stdin.readLineSync()?.trim() ?? '';
      if (input.isEmpty) {
        stdout.writeln('');
        return defaultIndex;
      }
      if (input.toLowerCase() == 'q') throw const ChecklistCancelled();
      final n = int.tryParse(input);
      if (n != null && n >= 1 && n <= items.length) {
        stdout.writeln('');
        return n - 1;
      }
    }
  }

  static void _render(
    String title,
    List<ChecklistItem> items,
    Set<String> selected,
    Set<String> locked,
    String lockedReason,
  ) {
    stdout.writeln('');
    stdout.writeln('  $title');
    stdout.writeln('');
    for (int i = 0; i < items.length; i++) {
      final isOn = selected.contains(items[i].label);
      final checkbox = isOn ? '[✓]' : '[ ]';
      final n = '${i + 1}'.padLeft(2);
      final lock = locked.contains(items[i].label) ? '  ($lockedReason)' : '';
      stdout.writeln('  $n)  $checkbox  ${items[i].label}$lock');
      if (items[i].description != null) {
        stdout.writeln('        ${items[i].description}');
      }
    }
    stdout.writeln('');
    stdout.writeln(
      '  Type a number to toggle. Press enter to confirm, q to quit.',
    );
  }
}

/// Represents a single checklist item option.
class ChecklistItem {
  /// Creates a checklist item with its default selected state.
  const ChecklistItem(
    this.label, {
    this.defaultOn = true,
    this.description,
    this.excludes = const <String>{},
  });

  /// The user-facing label shown in the checklist.
  final String label;

  /// Whether the item should be selected by default.
  final bool defaultOn;

  /// Optional one-line explanation of what selecting this item generates.
  final String? description;

  /// Labels that are deselected when this item is turned on. List the
  /// exclusion on both items to make the pair mutually exclusive.
  final Set<String> excludes;
}
