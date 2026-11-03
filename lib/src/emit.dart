import 'dart:math';

import 'schema.dart';

/// Renders the env class. Values marked `obfuscate` are XOR-ed with a random
/// key per code unit and decoded on first access; the others are literals.
String emitEnvClass({
  required String className,
  required List<EnvField> fields,
  required Map<String, String> values,
  required List<String> sources,
  Random? random,
}) {
  final rand = random ?? Random.secure();
  final buffer = StringBuffer()
    ..writeln('// coverage:ignore-file')
    ..writeln('// ignore_for_file: type=lint')
    ..writeln('// generated_from: ${sources.join(', ')}')
    ..writeln('abstract final class $className {');
  var first = true;
  for (final field in fields) {
    if (!first) buffer.writeln();
    first = false;
    final value = values[field.key] ?? '';
    final name = field.fieldName;
    if (field.description != null) buffer.writeln('  /// ${field.description}');
    if (!field.obfuscate || value.isEmpty) {
      buffer.writeln("  static const String $name = '${_escape(value)}';");
      continue;
    }
    final units = value.codeUnits;
    final key = [for (var i = 0; i < units.length; i++) rand.nextInt(1 << 32)];
    final data = [for (var i = 0; i < units.length; i++) units[i] ^ key[i]];
    final capitalized = name[0].toUpperCase() + name.substring(1);
    buffer
      ..writeln(
        '  static const List<int> _key$capitalized = <int>[${key.join(', ')}];',
      )
      ..writeln(
        '  static const List<int> _data$capitalized = <int>[${data.join(', ')}];',
      )
      ..writeln('  static final String $name = String.fromCharCodes(')
      ..writeln(
        '    List<int>.generate(_data$capitalized.length, (int i) => i, growable: false)',
      )
      ..writeln(
        '        .map((int i) => _data$capitalized[i] ^ _key$capitalized[i]),',
      )
      ..writeln('  );');
  }
  buffer.writeln('}');
  return buffer.toString();
}

String _escape(String value) => value
    .replaceAll(r'\', r'\\')
    .replaceAll("'", r"\'")
    .replaceAll(r'$', r'\$')
    .replaceAll('\n', r'\n')
    .replaceAll('\r', r'\r');
