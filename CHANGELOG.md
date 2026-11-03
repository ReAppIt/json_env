## 0.2.0

- Breaking: reads the values from a JSON object of strings (`values`, default
  `.env.json`) instead of a dotenv file (`env`), and validates nothing. Check
  the values before the build, for example with zod, and write what passed.
- Removed the dotenv parser and the `const`, `enum`, `minLength`,
  `maxLength`, `pattern`, `format` and `required` checks; `default` is no
  longer applied.

## 0.1.0

- Initial release: `@JsonEnv` on a `library;` directive generates an env class
  from a JSON Schema and a dotenv file, validating `const`, `enum`,
  `minLength`, `maxLength`, `pattern` (also under `allOf`) and `format: uri`,
  with `obfuscate: true` baking a value XOR-obfuscated.
