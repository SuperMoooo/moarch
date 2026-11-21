import 'package:moarch/src/commands/init_command.dart';
import 'package:test/test.dart';

void main() {
  final presets = InitCommand.presets;

  test('there are presets, each with a unique slug', () {
    expect(presets.length, greaterThanOrEqualTo(6));
    final slugs = presets.map((preset) => preset.slug).toList();
    expect(slugs.toSet(), hasLength(slugs.length));
  });

  for (final preset in presets) {
    group(preset.slug, () {
      test('requires only what it selects', () {
        expect(preset.selected, containsAll(preset.required));
      });

      // A preset that leans on a dependency rule would print a "Note: …
      // skipped" for a choice the user never made.
      test('survives the dependency rules unchanged', () {
        final stack = {...preset.selected};
        expect(InitCommand.reconcileSelection(stack), isEmpty);
        expect(stack, preset.selected);
      });
    });
  }

  test('reconcileSelection still drops what an option needs', () {
    final stack = {
      'Deep links (App Links + Universal Links)',
      'Offline sync (outbox + background)',
    };
    final notes = InitCommand.reconcileSelection(stack);
    expect(stack, isEmpty);
    expect(notes, hasLength(2));
  });
}
