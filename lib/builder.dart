import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/generator.dart';

Builder jsonEnvBuilder(BuilderOptions options) =>
    SharedPartBuilder([const JsonEnvGenerator()], 'json_env');
