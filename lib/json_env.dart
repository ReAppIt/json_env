/// Marks a library whose `.g.dart` part receives the generated env class.
///
/// Put it on the `library;` directive. [schema] is a JSON Schema naming the
/// keys and [values] a JSON object of their already validated values; both are
/// relative to the package root and listed under `sources` in `build.yaml`.
class JsonEnv {
  const JsonEnv(
    this.schema, {
    this.className = 'Env',
    this.values = '.env.json',
  });

  final String schema;
  final String className;
  final String values;
}
