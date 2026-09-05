# json_env

A `build_runner` builder that generates a Dart env class from a JSON Schema
and a dotenv file. Every value is validated against the schema at build time,
and keys marked `obfuscate` are baked XOR-obfuscated instead of as literals.

The schema is data, so it can come from anywhere: hand-written, or exported
from a TypeScript declaration with zod's `z.toJSONSchema`.

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
(hidden paths such as `.env` are otherwise invisible to build_runner):

```yaml
targets:
  $default:
    sources:
      - $package$
      - lib/**
      - .env
      - env.schema.json
```

`lib/config/env.dart`:

```dart
@JsonEnv('env.schema.json')
library;

import 'package:json_env/json_env.dart';

part 'env.g.dart';
```

`env.schema.json`:

```json
{
  "type": "object",
  "properties": {
    "APP_ORIGIN": { "type": "string", "const": "myapp" },
    "API_KEY": { "type": "string", "pattern": "^phc_[A-Za-z0-9]+$", "obfuscate": true },
    "OPTIONAL_KEY": { "type": "string", "description": "Empty when unset." }
  },
  "required": ["APP_ORIGIN", "API_KEY"]
}
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
`className` (default `Env`) and `env` (default `.env`).

## What is validated

For each declared key: required keys must be present and non-empty; a present
value must satisfy `const`, `enum`, `minLength`, `maxLength`, every `pattern`
(directly or inside `allOf`), and `format: "uri"` (scheme and host). Errors
name the key and the rule, never the value. Keys in the dotenv file that the
schema does not declare are ignored, so a folder-wide export is fine. Other
JSON Schema keywords are ignored.
