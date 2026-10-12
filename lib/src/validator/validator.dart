import '../models/diagnostics.dart';
import '../models/schema_node.dart';
import '../models/schema_value.dart';
import '../parser/html_extractor.dart';
import '../vocabulary/vocabulary.dart';
import 'property_checker.dart';
import 'type_checker.dart';
import 'value_checker.dart';

class ValidationResult {
  final List<ValidationDiagnostic> diagnostics;

  ValidationResult({required this.diagnostics});

  Iterable<ValidationDiagnostic> get errors =>
      diagnostics.where((d) => d.severity == Severity.error);

  Iterable<ValidationDiagnostic> get warnings =>
      diagnostics.where((d) => d.severity == Severity.warning);

  Iterable<ValidationDiagnostic> get infos =>
      diagnostics.where((d) => d.severity == Severity.info);

  bool get hasErrors => diagnostics.any((d) => d.severity == Severity.error);

  bool get hasWarnings =>
      diagnostics.any((d) => d.severity == Severity.warning);

  int get len => diagnostics.length;

  bool get isEmpty => diagnostics.isEmpty;

  @override
  String toString() =>
      'ValidationResult(errors: ${errors.length}, warnings: ${warnings.length}, infos: ${infos.length})';
}

/// Validates a [StructuredDataGraph] against Schema.org vocabulary.
ValidationResult validate(StructuredDataGraph graph) {
  final diagnostics = <ValidationDiagnostic>[];
  for (final node in graph.nodes) {
    final typeLabel =
        node.types.isEmpty ? '(unknown)' : node.types.join(', ');
    validateNode(node, typeLabel, diagnostics);
  }
  return ValidationResult(diagnostics: diagnostics);
}

/// Recursively validates a single [SchemaNode].
void validateNode(
  SchemaNode node,
  String path,
  List<ValidationDiagnostic> diagnostics,
) {
  for (final typeName in node.types) {
    checkType(typeName, path, diagnostics);
  }

  for (final entry in node.properties.entries) {
    final propName = entry.key;
    final values = entry.value;

    final propPath = '$path.$propName';
    checkProperty(propName, node.types, propPath, diagnostics);

    final propDef = lookupProperty(propName);
    if (propDef != null) {
      for (var i = 0; i < values.length; i++) {
        final value = values[i];
        final valuePath =
            values.length > 1 ? '$propPath[$i]' : propPath;

        checkValue(
          value,
          propName,
          propDef.expectedTypes,
          valuePath,
          diagnostics,
        );

        if (value is SchemaValueNode) {
          final nested = value.node;
          final nestedTypeLabel = nested.types.isEmpty
              ? '$valuePath.(unknown)'
              : '$valuePath.${nested.types.join(', ')}';
          validateNode(nested, nestedTypeLabel, diagnostics);
        }
      }
    }
  }
}
