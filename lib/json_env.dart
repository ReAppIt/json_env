/// Marks a library whose `.g.dart` part receives the generated env class.
///
/// Put it on the `library;` directive. [schema] is a JSON Schema and [env] a
/// dotenv file, both relative to the package root and both listed under
/// `sources` in `build.yaml` so edits rebuild the part.
class JsonEnv {
  const JsonEnv(this.schema, {this.className = 'Env', this.env = '.env'});

  final String schema;
  final String className;
  final String env;
}
