import '../models/diagnostics.dart';
import '../vocabulary/vocabulary.dart';
import 'levenshtein.dart';

void checkProperty(
  String propName,
  List<String> parentTypes,
  String path,
  List<ValidationDiagnostic> diagnostics,
) {
  if (propName.startsWith('@')) return;

  final propDef = lookupProperty(propName);
  if (propDef != null) {
    if (propDef.isSuperseded) {
      var message = "Property '$propName' is superseded";
      if (propDef.supersededBy != null) {
        message += ". Use '${propDef.supersededBy}' instead";
      }
      diagnostics.add(ValidationDiagnostic(
        path: path,
        severity: Severity.warning,
        code: DiagnosticCode.deprecatedProperty,
        message: message,
      ));
    }

    if (propDef.isPending) {
      diagnostics.add(ValidationDiagnostic(
        path: path,
        severity: Severity.info,
        code: DiagnosticCode.pendingProperty,
        message:
            "Property '$propName' is pending (not yet part of the stable Schema.org vocabulary)",
      ));
    }

    if (parentTypes.isNotEmpty) {
      final validForAnyType = parentTypes.any((typeName) {
        final td = lookupType(typeName);
        return td != null && td.hasProperty(propName);
      });

      if (!validForAnyType) {
        final typeList = parentTypes.join(', ');
        diagnostics.add(ValidationDiagnostic(
          path: path,
          severity: Severity.warning,
          code: DiagnosticCode.propertyNotForType,
          message: "Property '$propName' is not valid for type '$typeList'",
        ));
      }
    }
  } else {
    var message = "Unknown property '$propName'";
    final suggestion = suggestSimilar(propName, allPropertyNames);
    if (suggestion != null) {
      message += ". Did you mean '$suggestion'?";
    }

    diagnostics.add(ValidationDiagnostic(
      path: path,
      severity: Severity.error,
      code: DiagnosticCode.unknownProperty,
      message: message,
    ));
  }
}
