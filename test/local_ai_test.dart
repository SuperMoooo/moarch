import 'dart:io';

import 'package:moarch/src/templates/config/injector_templates.dart';
import 'package:moarch/src/templates/core/services_templates.dart';
import 'package:moarch/src/templates/misc/project_docs_templates.dart';
import 'package:moarch/src/utils/gradle_utils.dart';
import 'package:moarch/src/utils/package_versions.dart';
import 'package:moarch/src/utils/platform_requirements.dart';
import 'package:moarch/src/utils/scaffold_catalog.dart';
import 'package:moarch/src/utils/state_management.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const _manifest = '''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:label="demo">
        <activity
            android:name=".MainActivity">
        </activity>
    </application>
</manifest>
''';

void main() {
  group('LlmService', () {
    final source = ServicesTemplates.llmService();

    test('goes through the one shared initializer', () {
      expect(source, contains("import 'edge_ai.dart';"));
      expect(source, contains('await ensureEdgeAi();'));
      expect(source, isNot(contains('FlutterEdgeAi.initialize(')));
    });

    test('downloads a pinned catalog build in a foreground service', () {
      expect(source, contains('LiteRtLmModels.gemma4E2bIt.generic'));
      expect(
        source,
        contains('installModelFromCatalog(model, foreground: true)'),
      );
      expect(source, contains('isModelInstalled(model.file.installFilename)'));
    });

    test('loads text only, inside the window Gemma 4 keeps positions in', () {
      expect(source, contains('maxTokens = 2048'));
      expect(source, contains('supportImage: false'));
      expect(source, contains('supportAudio: false'));
    });

    test('marks the user turn, or the model answers nothing', () {
      expect(source, contains('Message.text(text: message, isUser: true)'));
      expect(source, contains('openChat()'));
      expect(source, isNot(contains('createChat(')));
    });
  });

  test('the core module registers it with a dispose', () {
    final withLlm = InjectorTemplates.coreModule(withLlm: true);
    expect(withLlm, contains("import '../../core/services/llm_service.dart';"));
    expect(withLlm, contains('registerLazySingleton<LlmService>'));
    expect(withLlm, contains('dispose: (service) => service.dispose()'));
    expect(InjectorTemplates.coreModule(), isNot(contains('LlmService')));
  });

  test('both packages are pinned as a pair', () {
    expect(PackageVersions.entry('flutter_edge_ai'), 'flutter_edge_ai: ^2.7.1');
    expect(
      PackageVersions.entry('flutter_edge_ai_litertlm'),
      'flutter_edge_ai_litertlm: ^1.21.0',
    );
  });

  group('ensureMinSdk', () {
    const template = '''
android {
    defaultConfig {
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
    }
}
''';

    test('floors the template default at 30', () {
      final out = GradleUtils.ensureMinSdk(template);
      expect(out, contains('minSdk = maxOf(flutter.minSdkVersion, 30)'));
      expect(out, contains('// At least 30'));
      expect(out, contains('targetSdk = flutter.targetSdkVersion'));
    });

    test('is idempotent', () {
      final once = GradleUtils.ensureMinSdk(template);
      expect(GradleUtils.ensureMinSdk(once), once);
    });

    test('raises a low literal and keeps a high one', () {
      expect(
        GradleUtils.ensureMinSdk('        minSdk = 24\n'),
        contains('minSdk = maxOf(flutter.minSdkVersion, 30)'),
      );
      const high = '        minSdk = 33\n';
      expect(GradleUtils.ensureMinSdk(high), high);
    });

    test('does not touch targetSdk or compileSdk', () {
      const other = 'compileSdk = 24\ntargetSdk = 24\n';
      expect(GradleUtils.ensureMinSdk(other), other);
    });
  });

  test('the manifest gets the foreground service the download runs in', () {
    final out = PlatformRequirement.localAi.patchManifest(_manifest);
    expect(out, contains('android.permission.INTERNET'));
    expect(out, contains('android.permission.FOREGROUND_SERVICE_DATA_SYNC'));
    final service = out.indexOf(
      'androidx.work.impl.foreground.SystemForegroundService',
    );
    expect(service, greaterThan(out.indexOf('<application')));
    expect(service, lessThan(out.indexOf('</application>')));
    expect(out, contains('android:foregroundServiceType="dataSync"'));
    expect(PlatformRequirement.localAi.patchManifest(out), out);
  });

  group('detection', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('moarch_local_ai_test');
      File(
        p.join(tempDir.path, 'pubspec.yaml'),
      ).writeAsStringSync('name: demo\n');
    });

    tearDown(() => tempDir.delete(recursive: true));

    test('reads the service off disk, and doctor checks its manifest', () {
      expect(ScaffoldContext.detect(tempDir.path).hasLlm, isFalse);
      File(p.join(tempDir.path, 'lib/core/services/llm_service.dart'))
        ..createSync(recursive: true)
        ..writeAsStringSync(ServicesTemplates.llmService());
      final context = ScaffoldContext.detect(tempDir.path);
      expect(context.hasLlm, isTrue);
      expect(
        PlatformRequirement.forProject(context),
        contains(PlatformRequirement.localAi),
      );
    });

    test('the catalog refreshes it', () {
      final spec = ScaffoldCatalog.all.singleWhere(
        (spec) => spec.name == 'llm-service',
      );
      expect(spec.path, 'lib/core/services/llm_service.dart');
    });
  });

  test('the services guide lists it only when it is there', () {
    const row = '`LlmService`';
    final services = ProjectDocsTemplates.all.singleWhere(
      (doc) => doc.slug == 'services-doc',
    );
    expect(
      services.render!(
        const DocsOptions(
          projectName: 'demo',
          stateManagement: StateManagement.riverpod,
          withLlm: true,
        ),
      ),
      contains(row),
    );
    expect(
      services.render!(
        const DocsOptions(
          projectName: 'demo',
          stateManagement: StateManagement.riverpod,
        ),
      ),
      isNot(contains(row)),
    );
  });
}
