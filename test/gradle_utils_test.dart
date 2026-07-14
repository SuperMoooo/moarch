import 'package:moarch/src/utils/gradle_utils.dart';
import 'package:test/test.dart';

const _defaultBuildGradle = '''
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.my_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.my_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
}

flutter {
    source = "../.."
}
''';

void main() {
  group('ensureCoreLibraryDesugaring', () {
    test('inserts the flag into an existing compileOptions block', () {
      final output =
          GradleUtils.ensureCoreLibraryDesugaring(_defaultBuildGradle);

      expect(
          output,
          contains('    compileOptions {\n'
              '        isCoreLibraryDesugaringEnabled = true\n'
              '        sourceCompatibility = JavaVersion.VERSION_11'));
    });

    test('appends a dependencies block with coreLibraryDesugaring', () {
      final output =
          GradleUtils.ensureCoreLibraryDesugaring(_defaultBuildGradle);

      expect(
        output,
        contains('dependencies {\n'
            '    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n'
            '}\n'),
      );
    });

    test('reuses an existing dependencies block instead of appending a new one',
        () {
      const withDeps = '''
android {
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.0")
}
''';

      final output = GradleUtils.ensureCoreLibraryDesugaring(withDeps);

      expect(
        output,
        contains('dependencies {\n'
            '    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n'
            '    implementation("androidx.core:core-ktx:1.13.0")'),
      );
      expect('dependencies {'.allMatches(output).length, equals(1));
    });

    test('creates a compileOptions block when none exists', () {
      const noCompileOptions = '''
android {
    namespace = "com.example.my_app"
}
''';

      final output = GradleUtils.ensureCoreLibraryDesugaring(noCompileOptions);

      expect(
          output,
          contains('    compileOptions {\n'
              '        isCoreLibraryDesugaringEnabled = true\n'
              '    }'));
    });

    test('is idempotent', () {
      final once = GradleUtils.ensureCoreLibraryDesugaring(_defaultBuildGradle);

      expect(
        GradleUtils.ensureCoreLibraryDesugaring(once),
        equals(once),
      );
    });

    test('skips files without an android block', () {
      const noAnchor = 'flutter {\n    source = "../.."\n}\n';

      expect(
        GradleUtils.ensureCoreLibraryDesugaring(noAnchor),
        equals(noAnchor),
      );
    });
  });
}
