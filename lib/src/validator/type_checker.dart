import '../models/diagnostics.dart';
import '../vocabulary/vocabulary.dart';
import 'levenshtein.dart';

void checkType(
  String typeName,
  String path,
  List<ValidationDiagnostic> diagnostics,
) {
  final typeDef = lookupType(typeName);
  if (typeDef != null) {
    if (typeDef.isAttic) {
      diagnostics.add(ValidationDiagnostic(
        path: path,
        severity: Severity.warning,
        code: DiagnosticCode.deprecatedType,
        message:
            "Type '$typeName' has been retired from Schema.org (moved to attic)",
      ));
    } else if (typeDef.isPending) {
      diagnostics.add(ValidationDiagnostic(
        path: path,
        severity: Severity.info,
        code: DiagnosticCode.pendingType,
        message:
            "Type '$typeName' is pending (not yet part of the stable Schema.org vocabulary)",
      ));
    }
  } else {
    var message = "Unknown type '$typeName'";
    final suggestion = suggestSimilar(typeName, allTypeNames);
    if (suggestion != null) {
      message += ". Did you mean '$suggestion'?";
    }

    diagnostics.add(ValidationDiagnostic(
      path: path,
      severity: Severity.error,
      code: DiagnosticCode.unknownType,
      message: message,
    ));
  }
}
