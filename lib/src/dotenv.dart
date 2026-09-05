/// Parses dotenv text: `KEY=value`, optional `export`, single or double
/// quotes, `#` comments. No interpolation; the first occurrence of a key wins.
Map<String, String> parseDotenv(String text) {
  final values = <String, String>{};
  for (final rawLine in text.split('\n')) {
    var line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    if (line.startsWith('export ')) line = line.substring(7).trimLeft();
    final separator = line.indexOf('=');
    if (separator <= 0) continue;
    final key = line.substring(0, separator).trim();
    if (values.containsKey(key)) continue;
    values[key] = _value(line.substring(separator + 1).trim());
  }
  return values;
}

String _value(String raw) {
  if (raw.length >= 2 && (raw[0] == '"' || raw[0] == "'")) {
    final quote = raw[0];
    final end = _closingQuote(raw, quote);
    if (end > 0) {
      final inner = raw.substring(1, end);
      return quote == '"'
          ? inner.replaceAll(r'\n', '\n').replaceAll(r'\"', '"')
          : inner.replaceAll(r"\'", "'");
    }
  }
  final comment = raw.indexOf(' #');
  return (comment >= 0 ? raw.substring(0, comment) : raw).trim();
}

// The first quote after the opening one that is not escaped, or -1.
int _closingQuote(String raw, String quote) {
  for (var i = 1; i < raw.length; i++) {
    if (raw[i] == quote && raw[i - 1] != r'\') return i;
  }
  return -1;
}
