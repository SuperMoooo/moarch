import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:moarch/src/commands/create/create_bloc_command.dart';
import 'package:moarch/src/commands/create/create_empty_factories_command.dart';
import 'package:moarch/src/commands/create/create_entity_copys_command.dart';
import 'package:moarch/src/commands/create/create_feature_command.dart';
import 'package:moarch/src/commands/create/create_flavors_command.dart';
import 'package:moarch/src/commands/create/create_model_command.dart';
import 'package:moarch/src/commands/create/create_theme_command.dart';
import 'package:moarch/src/commands/create/create_widget_command.dart';

/// Creates the feature-scaffolding CLI command.
class CreateCommand extends Command<int> {
  /// Creates the top-level feature generator command.
  CreateCommand({required Logger logger}) : _logger = logger {
    addSubcommand(CreateFeatureCommand(logger: logger));
    addSubcommand(CreateBlocCommand(logger: logger));
    addSubcommand(CreateModelCommand(logger: logger));
    addSubcommand(CreateEmptyFactoriesCommand(logger: logger));
    addSubcommand(CreateEntityCopysCommand(logger: logger));
    addSubcommand(CreateWidgetCommand(logger: logger));
    addSubcommand(CreateThemeCommand(logger: logger));
    addSubcommand(CreateFlavorsCommand(logger: logger));
  }

  final Logger _logger;

  @override
  String get name => 'create';

  @override
  String get description => 'Create a new feature or component.';

  @override
  Future<int> run() async {
    _logger.info(usage);
    return 0;
  }
}
