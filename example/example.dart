import 'package:mason_logger/mason_logger.dart';
import 'package:moarch/moarch.dart';

/// moarch is a CLI — install it once and run it from the terminal:
///
/// ```sh
/// dart pub global activate moarch
///
/// moarch init            # interactive scaffold (Clean Architecture + Riverpod)
/// moarch init --all      # the default structure, no prompts
///
/// moarch create feature orders                  # feature with selectable layers
/// moarch create model orders order              # entity + model, TODO fields
/// moarch create model orders order --from-json sample.json   # fields inferred
/// moarch create widget switch                   # one UI-kit widget on demand
/// moarch create widget all                      # the whole kit + preview screen
/// moarch create flavors                         # dev/staging/prod via
///                                               # flutter_flavorizr, one main.dart
///
/// moarch update          # refresh generated files against current templates
/// moarch update --diff   # ...showing what would change, line by line
/// moarch doctor --fix    # find and fix common scaffolding issues
/// ```
///
/// The README documents what every command generates.
///
/// The runner behind the executable can also be embedded and driven
/// programmatically, which is what this example does:
Future<void> main() async {
  final logger = Logger();
  final exitCode = await MoarchRunner().run(['--version']);
  logger.info('moarch exited with code $exitCode');
}
