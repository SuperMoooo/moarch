/// Generates the loading skeleton `moarch create feature` writes beside a
/// feature's view. The same on both stacks: it is plain widgets over fake data.
class SkeletonTemplates {
  SkeletonTemplates._();

  /// Returns the generated feature skeleton —
  /// `presentation/widgets/<name>_skeleton.dart`.
  ///
  /// [withModel] is false when the feature has no data layer, so there is no
  /// model to build the fake rows from.
  static String feature(String name, String cls, {bool withModel = true}) {
    final modelImport = withModel
        ? "\nimport '../../domain/models/${name}_model.dart';\n"
        : '\n';
    final fakes = withModel
        ? '''
  // TODO: give the fields your row draws fake values, e.g.
  // `${cls}Model.empty().copyWith(name: BoneMock.name)`.
  static final _items = List.generate(8, (_) => ${cls}Model.empty());

'''
        : '';
    final count = withModel ? '_items.length' : '8';
    final rowTodo = withModel
        ? '// TODO: draw the same row the view does, from `_items[index]`.'
        : '// TODO: draw the same row the view does.';

    return '''
import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
$modelImport
/// The $cls screen while its first load runs.
///
/// The view passes it to `skeleton:`, which wraps it in a Skeletonizer. That
/// shimmers the widgets it is given, so draw real widgets over fake data.
/// `BoneMock` hands out fake strings sized like real ones (a text's length
/// sets its bone's width): `BoneMock.name`, `BoneMock.title`,
/// `BoneMock.words(3)`, `BoneMock.email`, `BoneMock.date`, `BoneMock.phone`,
/// `BoneMock.paragraph`.
class ${cls}Skeleton extends StatelessWidget {
  const ${cls}Skeleton({super.key});

$fakes  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: $count,
      separatorBuilder: (context, index) => const Divider(height: 1),
      $rowTodo
      itemBuilder: (context, index) => ListTile(
        title: Text(BoneMock.title),
        subtitle: Text(BoneMock.words(4)),
      ),
    );
  }
}
''';
  }
}
