import '../models/schema_value.dart';

const List<String> schemaPrefixes = [
  'https://schema.org/',
  'http://schema.org/',
  'schema:',
];

/// Strips Schema.org URL prefixes from a type or property name.
String stripSchemaPrefix(String name) {
  for (final prefix in schemaPrefixes) {
    if (name.startsWith(prefix)) {
      return name.substring(prefix.length);
    }
  }
  return name;
}

/// Classifies a text string as [SchemaValueUrl], [SchemaValueDateTime],
/// or [SchemaValueText].
SchemaValue classifyTextValue(String s) {
  if (s.startsWith('http://') ||
      s.startsWith('https://') ||
      s.startsWith('mailto:')) {
    return SchemaValueUrl(s);
  }
  if (s.isNotEmpty &&
      s.codeUnitAt(0) >= 48 &&
      s.codeUnitAt(0) <= 57 &&
      isIsoDatetime(s)) {
    return SchemaValueDateTime(s);
  }
  return SchemaValueText(s);
}

/// Checks if a string matches an ISO 8601 date/datetime pattern (`YYYY-MM-DD...`).
bool isIsoDatetime(String s) {
  if (s.length < 10) return false;

  final codeUnits = s.codeUnits;
  bool isDigit(int index) {
    final c = codeUnits[index];
    return c >= 48 && c <= 57;
  }

  final validPattern = isDigit(0) &&
      isDigit(1) &&
      isDigit(2) &&
      isDigit(3) &&
      codeUnits[4] == 45 && // '-'
      isDigit(5) &&
      isDigit(6) &&
      codeUnits[7] == 45 && // '-'
      isDigit(8) &&
      isDigit(9);

  if (!validPattern) return false;

  final month = (codeUnits[5] - 48) * 10 + (codeUnits[6] - 48);
  final day = (codeUnits[8] - 48) * 10 + (codeUnits[9] - 48);

  if (month < 1 || month > 12 || day < 1 || day > 31) {
    return false;
  }

  if (s.length == 10) return true;

  final sep = codeUnits[10];
  // 'T', 't', 'Z', '+', '-'
  return sep == 84 || sep == 116 || sep == 90 || sep == 43 || sep == 45;
}
