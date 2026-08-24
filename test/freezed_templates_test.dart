import 'package:moarch/src/templates/core/core_templates.dart';
import 'package:moarch/src/templates/stack_templates.dart';
import 'package:moarch/src/utils/scaffold_catalog.dart';
import 'package:moarch/src/utils/state_management.dart';
import 'package:test/test.dart';

/// Every entity and model moarch writes, across both stacks and every variant.
///
/// They are generated the same way for a reason — a project holds features and
/// an auth feature side by side, and two conventions in one `data/` folder is
/// how the mapping in one of them stops being written at all.
Map<String, String> _entities(StackTemplates stack) => {
      'feature': stack.featureEntity('order', 'Order'),
      'feature (firestore)': stack.featureEntity(
        'order',
        'Order',
        useFirestore: true,
      ),
      'auth tokens': stack.authEntity(),
      'auth user': stack.firebaseAuthEntity(),
    };

Map<String, String> _models(StackTemplates stack) => {
      'feature': stack.featureModel('order', 'Order'),
      'feature (firestore)': stack.featureModel(
        'order',
        'Order',
        useFirestore: true,
      ),
      'auth tokens': stack.authModel(),
      'auth user': stack.firebaseAuthModel(),
      'auth user (firestore)': stack.firebaseAuthModel(withFirestore: true),
    };

void main() {
  const bloc = StackTemplates(StateManagement.bloc);
  const riverpod = StackTemplates(StateManagement.riverpod);

  group('stack parity', () {
    /// The source with its prose stripped.
    ///
    /// The two stacks explain the same class in their own terms — one names
    /// `emit`, the other a notifier's rebuild — and that difference is
    /// deliberate. The code under the comments is what must not drift.
    String code(String source) => source
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('///'))
        .join('\n');

    test('both stacks write the same entities and models', () {
      // Nothing about a data class depends on how state is held, so a fix
      // applied to one folder and not the other is what this catches.
      _entities(bloc).forEach((name, source) {
        expect(
          code(source),
          code(_entities(riverpod)[name]!),
          reason: '$name entity',
        );
      });
      _models(bloc).forEach((name, source) {
        expect(
          code(source),
          code(_models(riverpod)[name]!),
          reason: '$name model',
        );
      });
    });
  });

  group('entities', () {
    _entities(bloc).forEach((name, source) {
      test('$name is a freezed class', () {
        expect(source, contains('@freezed'));
        expect(source, contains('abstract class '));
        expect(source, contains(r'with _$'));
        expect(source, contains(".freezed.dart';"));
        // The redirecting factory is the field list.
        expect(source, contains('const factory '));
      });

      test('$name keeps JSON out of domain/', () {
        expect(source, isNot(contains('json_annotation')));
        expect(source, isNot(contains('@JsonKey')));
        expect(source, isNot(contains('JsonSerializable')));
        expect(source, isNot(contains('.g.dart')));
        expect(source, isNot(contains('fromJson')));
        expect(source, isNot(contains('toJson')));
      });
    });
  });

  group('models', () {
    _models(bloc).forEach((name, source) {
      test('$name is freezed and no longer extends its entity', () {
        expect(source, contains('@freezed'));
        expect(source, contains(".freezed.dart';"));
        expect(source, isNot(contains(RegExp(r'class \w+Model extends'))));
      });

      test('$name carries the private constructor freezed needs', () {
        // Without it the class cannot declare `toEntity()` and will not
        // compile — and the failure names the generated part, not this.
        expect(source, contains(RegExp(r'const \w+Model\._\(\);')));
      });

      test('$name maps to its entity in both directions', () {
        expect(source, contains(RegExp(r'factory \w+Model\.fromEntity\(')));
        expect(source, contains(RegExp(r'\w+Entity toEntity\(\)')));
      });
    });

    test('a model with JSON asks for the part that writes it', () {
      // freezed writes `toJson` for a class that has a `fromJson`; the
      // `.g.dart` part is what json_serializable fills in. One without the
      // other fails the build.
      for (final source in _models(bloc).values) {
        expect(
          source.contains('fromJson'),
          source.contains('.g.dart'),
          reason: 'fromJson and the .g.dart part travel together',
        );
      }
    });
  });

  group('the Firestore document shape', () {
    final model = bloc.featureModel('order', 'Order', useFirestore: true);

    test('reads the id off the snapshot and never writes it back', () {
      expect(
        model,
        contains('@JsonKey(includeToJson: false) required String id,'),
      );
      expect(model, contains("{...?doc.data(), 'id': doc.id}"));
    });

    test('points at the converter that keeps dates queryable', () {
      expect(model, contains('@TimestampConverter()'));
      expect(model, contains('timestamp_converter.dart'));
    });

    test('the REST model has neither', () {
      final rest = bloc.featureModel('order', 'Order');
      expect(rest, isNot(contains('includeToJson')));
      expect(rest, isNot(contains('fromDoc')));
      expect(rest, isNot(contains('cloud_firestore')));
    });
  });

  group('TimestampConverter', () {
    final source = CoreTemplates.timestampConverter();

    test('converts both ways, and tolerates what other writers store', () {
      expect(source, contains('class TimestampConverter'));
      expect(source, contains('implements JsonConverter<DateTime, Object?>'));
      expect(source, contains('Timestamp.fromDate(date)'));
      // A seed script or another SDK may have written a string or millis.
      expect(source, contains('json.toDate()'));
      expect(source, contains('DateTime.parse(json)'));
      expect(source, contains('DateTime.fromMillisecondsSinceEpoch(json'));
    });

    test('every read comes back in UTC', () {
      // `Timestamp.toDate()` hands back the device's local time, so the same
      // document reads as a different DateTime on two phones — and DateTime
      // counts its UTC flag in `==`, which a freezed entity leans on.
      expect(source, contains('json.toDate().toUtc()'));
      expect(source, contains('DateTime.parse(json).toUtc()'));
      expect(source, contains('isUtc: true'));
      expect(source, isNot(contains(RegExp(r'toDate\(\);'))));
    });

    test('has a nullable twin — the types have to line up', () {
      expect(source, contains('class NullableTimestampConverter'));
      expect(source, contains('implements JsonConverter<DateTime?, Object?>'));
    });

    test('is in the catalog, so update can refresh it', () {
      final spec = ScaffoldCatalog.all.firstWhere(
        (spec) => spec.name == 'timestamp-converter',
      );
      expect(spec.path, 'lib/core/network/timestamp_converter.dart');
      expect(spec.category, 'Network');
    });
  });

  group('the id-only equality is gone', () {
    test('no generated entity or model writes an == of its own', () {
      // The defect this replaced: `other is XEntity && other.id == id` made
      // every draft of a multi-step create form compare equal, because they
      // all share an empty id. Bloc's `emit` short-circuits on an equal state,
      // so every emit after the first was dropped and the form silently lost
      // what had been typed into it.
      for (final stack in [bloc, riverpod]) {
        for (final entry in {..._entities(stack), ..._models(stack)}.entries) {
          expect(
            entry.value,
            isNot(contains('operator ==')),
            reason: entry.key,
          );
          expect(
            entry.value,
            isNot(contains('get hashCode')),
            reason: entry.key,
          );
        }
      }
    });
  });

  group('.empty() survives', () {
    test('every entity still offers the blank freezed will not write', () {
      for (final entry in _entities(bloc).entries) {
        // Only the feature entity is a form's starting point; the auth pair is
        // never built empty, and inventing one would be a guess.
        if (!entry.key.startsWith('feature')) continue;
        expect(
          entry.value,
          contains(RegExp(r'factory \w+Entity\.empty\(\)')),
          reason: entry.key,
        );
      }
    });
  });
}
