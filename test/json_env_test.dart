import 'dart:io';

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:json_env/builder.dart';
import 'package:json_env/src/dotenv.dart';
import 'package:json_env/src/schema.dart';
import 'package:test/test.dart';

const schema = '''
{
  "type": "object",
  "properties": {
    "APP_ORIGIN": {"type": "string", "const": "myapp"},
    "API_KEY": {
      "type": "string",
      "minLength": 1,
      "allOf": [{"pattern": "^phc_[A-Za-z0-9]+\$"}],
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
@JsonEnv('test/env.schema.json', env: 'test/.env')
library;

import 'package:json_env/json_env.dart';

part 'env.g.dart';
''';

const validEnv = '''
# comment
APP_ORIGIN='myapp'
API_KEY="phc_abc123"
HOST=https://in9.example
UNRELATED=ignored
''';

Future<TestBuilderResult> build(String env) => testBuilder(
  jsonEnvBuilder(BuilderOptions.empty),
  {
    'json_env|lib/json_env.dart': File('lib/json_env.dart').readAsStringSync(),
    'a|test/env.schema.json': schema,
    'a|test/.env': env,
    'a|lib/env.dart': library,
  },
  rootPackage: 'a',
  flattenOutput: true,
);

Future<String> generate(String env) async {
  final result = await build(env);
  expect(result.succeeded, isTrue, reason: result.errors.join('\n'));
  return result.readerWriter.testing.readString(
    AssetId('a', 'lib/env.json_env.g.part'),
  );
}

Future<String> failure(String env) async {
  final result = await build(env);
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
    test(
      'emits literals, obfuscated values that decode, and defaults',
      () async {
        final out = await generate(validEnv);
        expect(out, contains('// ignore_for_file: type=lint'));
        expect(
          out,
          contains('// generated_from: test/env.schema.json, test/.env'),
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
      },
    );

    test('fails on a missing required key, naming the key only', () async {
      final errors = await failure(
        "APP_ORIGIN='myapp'\nHOST=https://in9.example\n",
      );
      expect(errors, contains('API_KEY: missing from test/.env'));
      expect(errors, isNot(contains('myapp')));
    });

    test('fails on a malformed value without echoing it', () async {
      final errors = await failure(
        "APP_ORIGIN='myapp'\nAPI_KEY=phx_secret\nHOST=not a url\n",
      );
      expect(errors, contains('API_KEY: does not match'));
      expect(errors, contains('HOST: is not a URI'));
      expect(errors, isNot(contains('phx_secret')));
    });
  });

  group('parseDotenv', () {
    test('handles quotes, comments, export and duplicates', () {
      final values = parseDotenv('''
export A='it\\'s'
B="line\\nbreak" # trailing
C=plain # comment
C=second
# D=commented
E=
''');
      expect(values, {'A': "it's", 'B': 'line\nbreak', 'C': 'plain', 'E': ''});
    });
  });

  group('validate', () {
    const field = EnvField(
      key: 'K',
      required: true,
      enumValues: ['a', 'bb'],
      minLength: 1,
      maxLength: 2,
      patterns: ['^[a-z]+\$'],
    );

    test('accepts a value meeting every rule', () {
      expect(validate(field, 'bb'), isEmpty);
    });

    test('reports each broken rule without the value', () {
      final failures = validate(field, 'CCC');
      expect(failures, hasLength(3));
      expect(failures.join(), isNot(contains('CCC')));
    });

    test('fieldName is the camelCase of the key', () {
      const f = EnvField(key: 'REVENUECAT_TEST_API_KEY', required: false);
      expect(f.fieldName, 'revenuecatTestApiKey');
    });
  });
}
