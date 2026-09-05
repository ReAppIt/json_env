import 'dart:io';

import 'package:build/build.dart';
import 'package:path/path.dart' as p;
import 'package:source_gen/source_gen.dart';

import '../json_env.dart';
import 'dotenv.dart';
import 'emit.dart';
import 'schema.dart';

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
    final className = reader.read('className').stringValue;
    final envPath = reader.read('env').stringValue;

    final List<EnvField> fields;
    try {
      fields = parseSchema(await _read(buildStep, schemaPath, library));
    } on FormatException catch (error) {
      throw InvalidGenerationSourceError(
        '$schemaPath: ${error.message}',
        element: library.element,
      );
    }
    final values = parseDotenv(await _read(buildStep, envPath, library));

    final problems = <String>[];
    for (final field in fields) {
      final value = values[field.key];
      if (value == null || value.isEmpty) {
        if (field.required && field.defaultValue == null) {
          problems.add('${field.key}: missing from $envPath');
        }
        continue;
      }
      for (final failure in validate(field, value)) {
        problems.add('${field.key}: $failure');
      }
    }
    if (problems.isNotEmpty) {
      throw InvalidGenerationSourceError(
        'Invalid environment in $envPath:\n  ${problems.join('\n  ')}',
        element: library.element,
      );
    }
    return emitEnvClass(
      className: className,
      fields: fields,
      values: values,
      sources: [schemaPath, envPath],
    );
  }

  // Root files such as `.env` are build assets only when listed under
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
      '$path is missing (add it to `sources` in build.yaml)',
      element: library.element,
    );
  }
}
