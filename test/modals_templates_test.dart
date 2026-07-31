import 'package:moarch/src/templates/ui/modals_templates.dart';
import 'package:moarch/src/utils/widget_catalog.dart';
import 'package:test/test.dart';

void main() {
  final output = ModalsTemplates.appActionSheet();

  group('appActionSheet', () {
    test('takes the shape of the platform, the way the pickers do', () {
      expect(
          output,
          contains(
              'enum AppActionSheetStyle { adaptive, material, cupertino }'));
      expect(output,
          contains('AppActionSheetStyle.adaptive => !Platform.isAndroid,'));
      expect(output, contains("import 'dart:io';"));
    });

    test('either shape can be forced', () {
      expect(output, contains('AppActionSheetStyle.material => false,'));
      expect(output, contains('AppActionSheetStyle.cupertino => true,'));
    });

    test('resolves to the picked value, and to null when dismissed', () {
      expect(output, contains('static Future<R?> show<R>('));
      expect(output, contains('if (picked == null) return null;'));
      expect(output, contains('return picked.value;'));
    });

    test('runs the callback after the sheet has closed', () {
      // A handler that pushes a route or opens a dialog while the sheet is
      // still closing fights the navigator for it.
      expect(
        output,
        contains('if (picked == null) return null;\n'
            '    // The sheet is gone by here, so a handler is free to push or open\n'
            '    // whatever it likes.\n'
            '    picked.onTap?.call();'),
      );
    });

    test('a destructive row owns its color', () {
      expect(output, contains('const AppSheetAction.destructive({'));
      expect(output, contains('isDestructive = true,'));
      expect(output,
          contains('if (action.isDestructive) return colorScheme.error;'));
      // The override is ignored on a destructive row rather than fighting it.
      expect(output, contains('color = null;'));
    });

    test('a disabled row is dimmed and refuses the tap', () {
      expect(output, contains('static const double _disabledOpacity = 0.38;'));
      expect(output, contains('if (!action.enabled) {'));
      expect(
          output,
          contains(
              'onTap: action.enabled ? () => _pick(context, action) : null,'));
    });

    test('the Material rows ink over the sheet, not under it', () {
      // showModalBottomSheet hands down a transparent Material, so ink on it
      // paints behind the sheet's own opaque surface.
      expect(
          output,
          contains(
              'Material(\n      // Its own Material, so the ink paints over the sheet'));
      expect(output, contains('color: Colors.transparent,'));
    });

    test('the Material shape reuses the sheet scaffold', () {
      expect(output, contains("import 'app_bottom_sheet_scaffold.dart';"));
      expect(output, contains('return AppBottomSheetScaffold('));
    });

    test('the Cupertino label stays centered against a trailing icon', () {
      expect(
          output,
          contains(
              'if (icon != null) const SizedBox(width: AppConstants.iconMedium),'));
      expect(output, contains('textAlign: TextAlign.center,'));
    });

    test('the cancel card is the Cupertino shape only', () {
      // Android dismisses a bottom sheet by its handle or the scrim; a cancel
      // row under one is not a thing it does.
      expect(output, contains('if (showCancel) ...['));

      final materialBuilder = output.substring(
        output.indexOf('Widget _buildMaterial(BuildContext context) {'),
        output.indexOf('// ── Cupertino'),
      );
      expect(materialBuilder, isNot(contains('showCancel')));
      expect(materialBuilder, isNot(contains('cancelLabel')));
    });

    test('the cancel row pops with nothing', () {
      expect(output, contains('onTap: () => Navigator.of(context).pop(),'));
    });

    test('a long list of actions scrolls rather than overflowing', () {
      expect('SingleChildScrollView('.allMatches(output).length, 2);
    });

    test('is in the catalog under Overlays, needing no router', () {
      final spec =
          WidgetCatalog.all.firstWhere((s) => s.name == 'action-sheet');
      expect(spec.file, 'overlays/app_action_sheet.dart');
      expect(spec.category, 'Overlays');
      expect(spec.deps, ['bottom-sheet']);
      expect(spec.packages, isEmpty);
      // It is shown from a BuildContext, unlike the context-free dialog and
      // modal helpers, so it costs the project no GoRouter.
      expect(spec.needsRouter, isFalse);
    });
  });
}
