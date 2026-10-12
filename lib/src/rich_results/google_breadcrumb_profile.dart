import '../models/diagnostics.dart';
import '../models/schema_node.dart';
import '../models/schema_value.dart';
import 'google_common.dart';
import 'profile_interface.dart';

class GoogleBreadcrumbProfile implements Profile {
  @override
  String get name => 'google';

  @override
  String get version => '2026-04-01';

  @override
  String get sourceUrl =>
      'https://developers.google.com/search/docs/appearance/structured-data/breadcrumb';

  @override
  List<String> get supportedTypes => const ['BreadcrumbList'];

  @override
  NodeProfileResult evaluateNode(
    SchemaNode node,
    List<ValidationDiagnostic> vocabDiagnostics,
  ) {
    const path = 'BreadcrumbList';
    final diagnostics = <ValidationDiagnostic>[];
    final requiredMissing = <String>[];

    final dItem = requireProperty(node, 'itemListElement', path);
    if (dItem != null) {
      requiredMissing.add('itemListElement');
      diagnostics.add(dItem);
    }

    final items = getNestedNodes(node, 'itemListElement');

    if (items.isEmpty && hasNonEmptyProperty(node, 'itemListElement')) {
      diagnostics.add(const ValidationDiagnostic(
        path: '$path.itemListElement',
        severity: Severity.error,
        code: DiagnosticCode.invalidFieldValue,
        message: 'itemListElement must contain ListItem objects',
      ));
    }

    final totalItems = items.length;

    for (var i = 0; i < totalItems; i++) {
      final item = items[i];
      final itemPath = '$path.itemListElement[$i]';
      final isLast = i == totalItems - 1;

      final dPos = requireProperty(item, 'position', itemPath);
      if (dPos != null) diagnostics.add(dPos);

      final dName = requireProperty(item, 'name', itemPath);
      if (dName != null) diagnostics.add(dName);

      if (!isLast) {
        final dItemRef = requireProperty(item, 'item', itemPath);
        if (dItemRef != null) diagnostics.add(dItemRef);
      }

      final posValues = item.properties['position'];
      if (posValues != null && posValues.isNotEmpty) {
        final expected = (i + 1).toDouble();
        final firstVal = posValues.first;
        num? actual;
        if (firstVal is SchemaValueNumber) {
          actual = firstVal.value;
        } else if (firstVal is SchemaValueText) {
          actual = num.tryParse(firstVal.value);
        }

        if (actual != null && actual != expected) {
          diagnostics.add(ValidationDiagnostic(
            path: '$itemPath.position',
            severity: Severity.warning,
            code: DiagnosticCode.invalidFieldValue,
            message:
                'Position should be ${i + 1}, got $actual. Positions must be sequential starting at 1',
          ));
        }
      }
    }

    final eligible = requiredMissing.isEmpty &&
        !diagnostics.any((d) => d.severity == Severity.error);

    return NodeProfileResult(
      typeEligibility: TypeEligibility(
        schemaType: 'BreadcrumbList',
        eligible: eligible,
        requiredMissing: requiredMissing,
        recommendedMissing: const [],
        fieldDiagnostics: diagnostics,
      ),
    );
  }
}
