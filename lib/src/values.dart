import 'dart:convert';

/// Parses the values file: a JSON object of strings, validated before the build.
///
/// Throws [FormatException] for anything else, naming the key, never the value.
Map<String, String> parseValues(String json) {
  final root = jsonDecode(json);
  if (root is! Map<String, dynamic>) {
    throw const FormatException('the values must be a JSON object');
  }
  return {
    for (final MapEntry(:key, :value) in root.entries)
      key: value is String
          ? value
          : throw FormatException('$key: the value must be a string'),
  };
}
