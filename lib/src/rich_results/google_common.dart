import '../models/diagnostics.dart';
import '../models/schema_node.dart';
import '../models/schema_value.dart';

ValidationDiagnostic? requireProperty(
  SchemaNode node,
  String prop,
  String path,
) {
  if (hasNonEmptyProperty(node, prop)) {
    return null;
  }
  return ValidationDiagnostic(
    path: '$path.$prop',
    severity: Severity.error,
    code: DiagnosticCode.requiredFieldMissing,
    message: "Required field '$prop' is missing",
  );
}

ValidationDiagnostic? recommendProperty(
  SchemaNode node,
  String prop,
  String path,
) {
  if (hasNonEmptyProperty(node, prop)) {
    return null;
  }
  return ValidationDiagnostic(
    path: '$path.$prop',
    severity: Severity.warning,
    code: DiagnosticCode.recommendedFieldMissing,
    message: "Recommended field '$prop' is missing",
  );
}

ValidationDiagnostic? requireOneOf(
  SchemaNode node,
  List<String> props,
  String path,
  Severity severity,
) {
  if (props.any((p) => hasNonEmptyProperty(node, p))) {
    return null;
  }
  final list = props.join("' or '");
  final code = severity == Severity.error
      ? DiagnosticCode.requiredFieldMissing
      : DiagnosticCode.recommendedFieldMissing;
  return ValidationDiagnostic(
    path: path,
    severity: severity,
    code: code,
    message: "At least one of '$list' should be present",
  );
}

List<ValidationDiagnostic> validateNested(
  SchemaNode node,
  String prop,
  String expectedType,
  List<String> required,
  List<String> recommended,
  String path,
) {
  final diagnostics = <ValidationDiagnostic>[];
  final values = node.properties[prop];
  if (values == null) return diagnostics;

  for (var i = 0; i < values.length; i++) {
    final value = values[i];
    final nestedPath =
        values.length > 1 ? '$path.$prop[$i]' : '$path.$prop';

    if (value is SchemaValueNode) {
      final nested = value.node;

      for (final req in required) {
        if (!hasNonEmptyProperty(nested, req)) {
          diagnostics.add(ValidationDiagnostic(
            path: '$nestedPath.$req',
            severity: Severity.error,
            code: DiagnosticCode.nestedRequiredFieldMissing,
            message:
                "Required field '$req' is missing in nested $expectedType",
          ));
        }
      }

      for (final rec in recommended) {
        if (!hasNonEmptyProperty(nested, rec)) {
          diagnostics.add(ValidationDiagnostic(
            path: '$nestedPath.$rec',
            severity: Severity.warning,
            code: DiagnosticCode.recommendedFieldMissing,
            message:
                "Recommended field '$rec' is missing in nested $expectedType",
          ));
        }
      }
    }
  }

  return diagnostics;
}

bool hasNonEmptyProperty(SchemaNode node, String prop) {
  final vals = node.properties[prop];
  return vals != null && vals.isNotEmpty;
}

List<SchemaNode> getNestedNodes(SchemaNode node, String prop) {
  final vals = node.properties[prop];
  if (vals == null) return [];
  final res = <SchemaNode>[];
  for (final v in vals) {
    if (v is SchemaValueNode) {
      res.add(v.node);
    }
  }
  return res;
}
