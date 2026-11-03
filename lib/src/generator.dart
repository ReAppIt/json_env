import 'dart:io';

import 'package:build/build.dart';
import 'package:path/path.dart' as p;
import 'package:source_gen/source_gen.dart';

import '../json_env.dart';
import 'emit.dart';
import 'schema.dart';
import 'values.dart';

/// Emits the env class for a library carrying [JsonEnv] on its `library;`
/// directive; every other library yields nothing.
final class JsonEnvGenerator extends Generator {
  const JsonEnvGenerator();

  static const _checker = TypeChecker.typeNamed(JsonEnv, inPackage: 'json_env');

  @override
  Future<String?> generate(LibraryReader library, BuildStep buildStep) async {
    final annotation = _checker.firstAnnotationOf(library.element);
    if (annotation == null) return null;
    final reader = ConstantReader(annotation);
    final schemaPath = reader.read('schema').stringValue;
    final valuesPath = reader.read('values').stringValue;
    return emitEnvClass(
      className: reader.read('className').stringValue,
      fields: await _parse(buildStep, library, schemaPath, parseSchema),
      values: await _parse(buildStep, library, valuesPath, parseValues),
      sources: [schemaPath, valuesPath],
    );
  }

  Future<T> _parse<T>(
    BuildStep buildStep,
    LibraryReader library,
    String path,
    T Function(String text) parse,
  ) async {
    final text = await _read(buildStep, path, library);
    try {
      return parse(text);
    } on FormatException catch (error) {
      throw InvalidGenerationSourceError(
        '$path: ${error.message}',
        element: library.element,
      );
    }
  }

  // Root files such as `.env.json` are build assets only when listed under
  // `sources`; the disk fallback keeps an unlisted file working, untracked.
  Future<String> _read(
    BuildStep buildStep,
    String path,
    LibraryReader library,
  ) async {
    final id = AssetId(buildStep.inputId.package, path);
    if (await buildStep.canRead(id)) return buildStep.readAsString(id);
    final file = File(p.join(Directory.current.path, path));
    if (await file.exists()) return file.readAsString();
    throw InvalidGenerationSourceError(
      '$path is missing: write it before the build and list it under '
      '`sources` in build.yaml',
      element: library.element,
    );
  }
}
