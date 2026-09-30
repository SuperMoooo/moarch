import 'package:moarch/src/templates/misc/skeleton_templates.dart';
import 'package:moarch/src/templates/stack_templates.dart';
import 'package:moarch/src/utils/state_management.dart';
import 'package:test/test.dart';

void main() {
  group('SkeletonTemplates.feature', () {
    final output = SkeletonTemplates.feature('orders', 'Orders');

    test('is a widget named after the feature', () {
      expect(
        output,
        contains('class OrdersSkeleton extends StatelessWidget {'),
      );
      expect(output, contains('const OrdersSkeleton({super.key});'));
    });

    test('draws a separated list over fake models', () {
      expect(
        output,
        contains("import '../../domain/models/orders_model.dart';"),
      );
      expect(
        output,
        contains(
          'static final _items = List.generate(8, (_) => OrdersModel.empty());',
        ),
      );
      expect(output, contains('return ListView.separated('));
      expect(output, contains('itemCount: _items.length,'));
      expect(
        output,
        contains('physics: const NeverScrollableScrollPhysics(),'),
      );
    });

    test('says how BoneMock sizes the bones', () {
      expect(
        output,
        contains("import 'package:skeletonizer/skeletonizer.dart';"),
      );
      expect(output, contains('`BoneMock.name`'));
      expect(output, contains('BoneMock.words(4)'));
    });

    test('without a data layer there is no model to fake', () {
      final plain = SkeletonTemplates.feature(
        'orders',
        'Orders',
        withModel: false,
      );

      expect(plain, isNot(contains('orders_model.dart')));
      expect(plain, isNot(contains('_items')));
      expect(plain, contains('itemCount: 8,'));
    });

    test('is the same on both stacks', () {
      expect(
        const StackTemplates(
          StateManagement.bloc,
        ).featureSkeleton('orders', 'Orders'),
        const StackTemplates(
          StateManagement.riverpod,
        ).featureSkeleton('orders', 'Orders'),
      );
    });
  });
}
