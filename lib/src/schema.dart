import 'dart:convert';

/// One key of the env, with the generator hints its schema property carries.
final class EnvField {
  const EnvField({required this.key, this.obfuscate = false, this.description});

  final String key;
  final bool obfuscate;
  final String? description;

  /// `APP_ORIGIN` → `appOrigin`.
  String get fieldName => key.toLowerCase().replaceAllMapped(
    RegExp('_([a-z0-9])'),
    (match) => match[1]!.toUpperCase(),
  );
}

/// Parses the `properties` of a JSON Schema object, in declaration order.
///
/// Throws [FormatException] when the schema declares none.
List<EnvField> parseSchema(String json) {
  final root = jsonDecode(json);
  if (root is! Map<String, dynamic>) {
    throw const FormatException('the schema must be a JSON object');
  }
  final properties = root['properties'];
  if (properties is! Map<String, dynamic>) {
    throw const FormatException('the schema must declare `properties`');
  }
  return [
    for (final MapEntry(:key, :value) in properties.entries)
      EnvField(
        key: key,
        obfuscate: value is Map && value['obfuscate'] == true,
        description: value is Map ? value['description'] as String? : null,
      ),
  ];
}
