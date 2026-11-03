import 'dart:io';

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:json_env/builder.dart';
import 'package:json_env/src/schema.dart';
import 'package:json_env/src/values.dart';
import 'package:test/test.dart';

const schema = '''
{
  "type": "object",
  "properties": {
    "APP_ORIGIN": {"type": "string", "const": "myapp"},
    "API_KEY": {
      "type": "string",
      "pattern": "^phc_[A-Za-z0-9]+\$",
      "obfuscate": true,
      "description": "The project key."
    },
    "OPTIONAL_KEY": {"type": "string"},
    "HOST": {"type": "string", "format": "uri"}
  },
  "required": ["APP_ORIGIN", "API_KEY", "HOST"]
}
''';

const library = '''
@JsonEnv('test/env.schema.json', values: 'test/.env.json')
library;

import 'package:json_env/json_env.dart';

part 'env.g.dart';
''';

const validValues = '''
{
  "APP_ORIGIN": "myapp",
  "API_KEY": "phc_abc123",
  "HOST": "https://in9.example",
  "UNRELATED": "ignored"
}
''';

Future<TestBuilderResult> build(String values) => testBuilder(
  jsonEnvBuilder(BuilderOptions.empty),
  {
    'json_env|lib/json_env.dart': File('lib/json_env.dart').readAsStringSync(),
    'a|test/env.schema.json': schema,
    'a|test/.env.json': values,
    'a|lib/env.dart': library,
  },
  rootPackage: 'a',
  flattenOutput: true,
);

Future<String> generate(String values) async {
  final result = await build(values);
  expect(result.succeeded, isTrue, reason: result.errors.join('\n'));
  return result.readerWriter.testing.readString(
    AssetId('a', 'lib/env.json_env.g.part'),
  );
}

Future<String> failure(String values) async {
  final result = await build(values);
  expect(result.succeeded, isFalse);
  return result.errors.join('\n');
}

List<int> ints(String source, String name) {
  final match = RegExp('$name = <int>\\[([^\\]]*)\\]').firstMatch(source)!;
  return [
    for (final piece in match[1]!.split(','))
      if (piece.trim().isNotEmpty) int.parse(piece.trim()),
  ];
}

void main() {
  group('generator', () {
    test('emits literals, obfuscated values that decode, and blanks', () async {
      final out = await generate(validValues);
      expect(out, contains('// ignore_for_file: type=lint'));
      expect(
        out,
        contains('// generated_from: test/env.schema.json, test/.env.json'),
      );
      expect(out, contains('abstract final class Env {'));
      expect(out, contains("static const String appOrigin = 'myapp';"));
      expect(
        out,
        contains("static const String host = 'https://in9.example';"),
      );
      expect(out, contains("static const String optionalKey = '';"));
      expect(out, contains('  /// The project key.\n'));
      expect(
        out,
        contains('static final String apiKey = String.fromCharCodes('),
      );
      expect(out, isNot(contains('phc_abc123')));
      final key = ints(out, '_keyApiKey');
      final data = ints(out, '_dataApiKey');
      final decoded = String.fromCharCodes([
        for (var i = 0; i < data.length; i++) data[i] ^ key[i],
      ]);
      expect(decoded, 'phc_abc123');
      expect(out, isNot(contains('UNRELATED')));
    });

    test('bakes a value as given, validating nothing', () async {
      final out = await generate(
        r"""{"APP_ORIGIN": "other", "HOST": "it's $HOME"}""",
      );
      expect(out, contains("static const String appOrigin = 'other';"));
      expect(out, contains(r"static const String host = 'it\'s \$HOME';"));
      expect(out, contains("static const String apiKey = '';"));
    });

    test('fails on a non-string value, naming the key only', () async {
      final errors = await failure('{"API_KEY": ["phc_leaked"]}');
      expect(errors, contains('test/.env.json: API_KEY: the value must be'));
      expect(errors, isNot(contains('phc_leaked')));
    });
  });

  group('parseValues', () {
    test('reads a JSON object of strings', () {
      expect(parseValues('{"A": "1", "B": ""}'), {'A': '1', 'B': ''});
    });

    test('rejects anything but an object', () {
      expect(() => parseValues('["A"]'), throwsFormatException);
    });
  });

  group('parseSchema', () {
    test('keeps declaration order and the generator hints', () {
      final fields = parseSchema(schema);
      expect(
        [for (final f in fields) f.key],
        ['APP_ORIGIN', 'API_KEY', 'OPTIONAL_KEY', 'HOST'],
      );
      expect(fields[1].obfuscate, isTrue);
      expect(fields[1].description, 'The project key.');
    });

    test('fieldName is the camelCase of the key', () {
      const f = EnvField(key: 'REVENUECAT_TEST_API_KEY');
      expect(f.fieldName, 'revenuecatTestApiKey');
    });
  });
}
