## 0.1.0

- Initial release: `@JsonEnv` on a `library;` directive generates an env class
  from a JSON Schema and a dotenv file, validating `const`, `enum`,
  `minLength`, `maxLength`, `pattern` (also under `allOf`) and `format: uri`,
  with `obfuscate: true` baking a value XOR-obfuscated.
