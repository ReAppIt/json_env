# json_env

A `build_runner` builder that generates a Dart env class from a JSON Schema
and a JSON object of values. Keys marked `obfuscate` are baked XOR-obfuscated
instead of as literals.

It validates nothing: check the values before the build and write what passed
as the values file. With zod, `z.toJSONSchema` exports the schema and `parse`
output is the values file, so one declaration drives both.

## Usage

`pubspec.yaml`:

```yaml
dependencies:
  json_env:
    git: https://github.com/ReAppIt/json_env.git
dev_dependencies:
  build_runner: ^2.7.0
```

`build.yaml` — both files live at the package root, so list them as sources
(hidden paths such as `.env.json` are otherwise invisible to build_runner):

```yaml
targets:
  $default:
    sources:
      - $package$
      - lib/**
      - .env.json
      - env.schema.json
```

`lib/config/env.dart`:

```dart
@JsonEnv('env.schema.json')
library;

import 'package:json_env/json_env.dart';

part 'env.g.dart';
```

`env.schema.json` — only `properties` is read, and of each property only
`obfuscate` and `description`:

```json
{
  "type": "object",
  "properties": {
    "APP_ORIGIN": { "type": "string", "const": "myapp" },
    "API_KEY": { "type": "string", "obfuscate": true },
    "OPTIONAL_KEY": { "type": "string", "description": "Empty when unset." }
  }
}
```

`.env.json` — the validated values, all strings. A declared key it lacks is
baked as `''`; a key the schema does not declare is ignored:

```json
{ "APP_ORIGIN": "myapp", "API_KEY": "phc_abc123" }
```

`dart run build_runner build` then emits `env.g.dart`:

```dart
abstract final class Env {
  static const String appOrigin = 'myapp';
  static final String apiKey = /* decoded from two const List<int> */;
  /// Empty when unset.
  static const String optionalKey = '';
}
```

Field names are the camelCase form of the keys. `@JsonEnv` takes
`className` (default `Env`) and `values` (default `.env.json`). A values
file that is not a JSON object of strings fails the build, naming the key,
never the value.
