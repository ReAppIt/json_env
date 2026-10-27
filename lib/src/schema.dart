import 'dart:convert';

/// One key of the env: the JSON Schema subset the builder understands.
final class EnvField {
  const EnvField({
    required this.key,
    required this.required,
    this.constValue,
    this.enumValues,
    this.minLength,
    this.maxLength,
    this.patterns = const [],
    this.format,
    this.obfuscate = false,
    this.description,
    this.defaultValue,
  });

  final String key;
  final bool required;
  final String? constValue;
  final List<String>? enumValues;
  final int? minLength;
  final int? maxLength;
  final List<String> patterns;
  final String? format;
  final bool obfuscate;
  final String? description;
  final String? defaultValue;

  /// `APP_ORIGIN` → `appOrigin`.
  String get fieldName => key.toLowerCase().replaceAllMapped(
    RegExp('_([a-z0-9])'),
    (match) => match[1]!.toUpperCase(),
  );
}

/// Parses the `properties` of a JSON Schema object, in declaration order.
///
/// Throws [FormatException] for a property that is not a string.
List<EnvField> parseSchema(String json) {
  final root = jsonDecode(json);
  if (root is! Map<String, dynamic>) {
    throw const FormatException('the schema must be a JSON object');
  }
  final properties = root['properties'];
  if (properties is! Map<String, dynamic>) {
    throw const FormatException('the schema must declare `properties`');
  }
  final required = (root['required'] as List?)?.cast<String>().toSet() ?? {};
  return [
    for (final MapEntry(:key, :value) in properties.entries)
      _parseField(key, value, required: required.contains(key)),
  ];
}

EnvField _parseField(String key, Object? raw, {required bool required}) {
  if (raw is! Map<String, dynamic>) {
    throw FormatException('$key: property must be an object');
  }
  final type = raw['type'];
  if (type != null && type != 'string') {
    throw FormatException('$key: only string properties are supported');
  }
  return EnvField(
    key: key,
    required: required,
    constValue: raw['const'] as String?,
    enumValues: (raw['enum'] as List?)?.cast<String>(),
    minLength: raw['minLength'] as int?,
    maxLength: raw['maxLength'] as int?,
    patterns: [
      if (raw['pattern'] is String) raw['pattern'] as String,
      for (final part in (raw['allOf'] as List?) ?? const [])
        if (part is Map && part['pattern'] is String) part['pattern'] as String,
    ],
    format: raw['format'] as String?,
    obfuscate: raw['obfuscate'] == true,
    description: raw['description'] as String?,
    defaultValue: raw['default'] as String?,
  );
}

/// The rules a present value breaks, worded without the value.
List<String> validate(EnvField field, String value) {
  final failures = <String>[];
  if (field.constValue != null && value != field.constValue) {
    failures.add('must equal the declared constant');
  }
  if (field.enumValues != null && !field.enumValues!.contains(value)) {
    failures.add('must be one of the declared values');
  }
  if (field.minLength != null && value.length < field.minLength!) {
    failures.add('is shorter than ${field.minLength} characters');
  }
  if (field.maxLength != null && value.length > field.maxLength!) {
    failures.add('is longer than ${field.maxLength} characters');
  }
  for (final pattern in field.patterns) {
    if (!RegExp(pattern).hasMatch(value)) {
      failures.add('does not match $pattern');
    }
  }
  if (field.format == 'uri') {
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      failures.add('is not a URI with a scheme and a host');
    }
  }
  return failures;
}
