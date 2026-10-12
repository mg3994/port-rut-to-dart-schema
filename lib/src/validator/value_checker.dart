import '../models/diagnostics.dart';
import '../models/schema_value.dart';
import '../vocabulary/vocabulary.dart';

const List<String> primitiveTypes = [
  'Text',
  'Number',
  'Boolean',
  'Date',
  'DateTime',
  'Time',
  'URL',
  'Integer',
  'Float',
  'CssSelectorType',
  'PronounceableText',
  'XPathType',
];

void checkValue(
  SchemaValue value,
  String propName,
  List<String> expectedTypes,
  String path,
  List<ValidationDiagnostic> diagnostics,
) {
  if (expectedTypes.isEmpty) return;

  switch (value) {
    case SchemaValueText(value: final text):
      _checkTextValue(text, propName, expectedTypes, path, diagnostics);
    case SchemaValueUrl():
      _checkUrlValue(expectedTypes, path, diagnostics);
    case SchemaValueNode(node: final node):
      _checkNodeValue(node.types, propName, expectedTypes, path, diagnostics);
    case SchemaValueNumber():
      _checkNumberValue(expectedTypes, path, diagnostics);
    case SchemaValueBoolean():
      _checkBooleanValue(expectedTypes, path, diagnostics);
    case SchemaValueDateTime():
      _checkDatetimeValue(expectedTypes, path, diagnostics);
  }
}

void _checkTextValue(
  String text,
  String propName,
  List<String> expected,
  String path,
  List<ValidationDiagnostic> diagnostics,
) {
  if (_hasAny(
    expected,
    ['Text', 'PronounceableText', 'CssSelectorType', 'XPathType'],
  )) {
    return;
  }

  if (_hasAny(expected, ['Date', 'DateTime', 'Time'])) {
    return;
  }

  if (_hasAny(expected, ['Number', 'Integer', 'Float'])) {
    if (num.tryParse(text) == null) {
      diagnostics.add(ValidationDiagnostic(
        path: path,
        severity: Severity.warning,
        code: DiagnosticCode.invalidNumber,
        message: 'Property \'$propName\' expects a number, got text: "$text"',
      ));
    }
    return;
  }

  if (_hasAny(expected, ['Boolean']) && (text == 'true' || text == 'false')) {
    diagnostics.add(ValidationDiagnostic(
      path: path,
      severity: Severity.warning,
      code: DiagnosticCode.invalidBoolean,
      message:
          'Property \'$propName\' expects a boolean, got string "$text". Use a boolean value instead',
    ));
    return;
  }

  if (_hasAny(expected, ['URL'])) {
    if (!text.startsWith('http://') &&
        !text.startsWith('https://') &&
        !text.startsWith('mailto:')) {
      diagnostics.add(ValidationDiagnostic(
        path: path,
        severity: Severity.warning,
        code: DiagnosticCode.expectedUrlGotText,
        message: 'Property \'$propName\' expects a URL',
      ));
    }
    return;
  }

  final enumTypes =
      expected.where((t) => !primitiveTypes.contains(t)).toList();

  if (enumTypes.isNotEmpty) {
    if (lookupEnumMember(text) != null) {
      return;
    }
    if (lookupType(text) != null) {
      return;
    }

    final expectedList = enumTypes.map((t) => '\'$t\'').join(', ');
    diagnostics.add(ValidationDiagnostic(
      path: path,
      severity: Severity.error,
      code: DiagnosticCode.invalidEnumValue,
      message:
          '\'$text\' is not a valid value for property \'$propName\' (expected $expectedList member)',
    ));
    return;
  }

  final expectedList = expected.join(', ');
  diagnostics.add(ValidationDiagnostic(
    path: path,
    severity: Severity.error,
    code: DiagnosticCode.invalidValueType,
    message: 'Property \'$propName\' expects $expectedList, got Text',
  ));
}

void _checkUrlValue(
  List<String> expected,
  String path,
  List<ValidationDiagnostic> diagnostics,
) {}

void _checkNodeValue(
  List<String> nodeTypes,
  String propName,
  List<String> expected,
  String path,
  List<ValidationDiagnostic> diagnostics,
) {
  final allPrimitive = expected.every((t) => primitiveTypes.contains(t));
  if (allPrimitive) {
    final expectedList = expected.join(', ');
    diagnostics.add(ValidationDiagnostic(
      path: path,
      severity: Severity.error,
      code: DiagnosticCode.expectedTextGotNode,
      message:
          'Property \'$propName\' expects $expectedList, not a nested object',
    ));
    return;
  }

  if (nodeTypes.isEmpty) return;

  final matches = nodeTypes.any((nodeType) {
    return expected.any((expectedType) {
      if (primitiveTypes.contains(expectedType)) return false;
      if (nodeType == expectedType) return true;
      return isSubtype(nodeType, expectedType);
    });
  });

  if (!matches) {
    final nodeTypeList = nodeTypes.join(', ');
    final expectedList = expected
        .where((t) => !primitiveTypes.contains(t))
        .map((t) => '\'$t\'')
        .join(', ');
    diagnostics.add(ValidationDiagnostic(
      path: path,
      severity: Severity.error,
      code: DiagnosticCode.invalidValueType,
      message:
          'Property \'$propName\' expects $expectedList, got \'$nodeTypeList\'',
    ));
  }
}

void _checkNumberValue(
  List<String> expected,
  String path,
  List<ValidationDiagnostic> diagnostics,
) {}

void _checkBooleanValue(
  List<String> expected,
  String path,
  List<ValidationDiagnostic> diagnostics,
) {}

void _checkDatetimeValue(
  List<String> expected,
  String path,
  List<ValidationDiagnostic> diagnostics,
) {}

bool _hasAny(List<String> expected, List<String> candidates) {
  return candidates.any((c) => expected.contains(c));
}
