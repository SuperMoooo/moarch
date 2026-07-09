import 'dart:io';

import 'package:moarch/src/runner.dart';

Future<void> main(List<String> arguments) async {
  exitCode = await MoarchRunner().run(arguments);
}
