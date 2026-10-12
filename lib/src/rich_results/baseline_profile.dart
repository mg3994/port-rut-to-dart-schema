import '../models/diagnostics.dart';
import '../models/schema_node.dart';
import '../models/schema_value.dart';
import 'google_common.dart';
import 'profile_interface.dart';

class BaselineProfile implements Profile {
  @override
  String get name => 'baseline';

  @override
  String get version => '2026-04-01';

  @override
  String get sourceUrl => 'https://schema.org/docs/gs.html';

  @override
  List<String> get supportedTypes => const ['Thing'];

  @override
  NodeProfileResult evaluateNode(
    SchemaNode node,
    List<ValidationDiagnostic> vocabDiagnostics,
  ) {
    final typeName = node.types.isNotEmpty ? node.types.first : 'Thing';
    final path = typeName;
    final diagnostics = <ValidationDiagnostic>[];
    final recommendedMissing = <String>[];

    final dName = requireOneOf(node, const ['name', 'headline'], path, Severity.warning);
    if (dName != null) {
      recommendedMissing.add('name/headline');
      diagnostics.add(dName);
    }

    final dImg = recommendProperty(node, 'image', path);
    if (dImg != null) {
      recommendedMissing.add('image');
      diagnostics.add(dImg);
    }

    final dDesc = recommendProperty(node, 'description', path);
    if (dDesc != null) {
      recommendedMissing.add('description');
      diagnostics.add(dDesc);
    }

    checkUrlHttps(node, 'url', path, diagnostics);
    checkUrlHttps(node, 'image', path, diagnostics);

    final eligible = !diagnostics.any((d) => d.severity == Severity.error);

    return NodeProfileResult(
      typeEligibility: TypeEligibility(
        schemaType: typeName,
        eligible: eligible,
        requiredMissing: const [],
        recommendedMissing: recommendedMissing,
        fieldDiagnostics: diagnostics,
      ),
    );
  }
}

void checkUrlHttps(
  SchemaNode node,
  String prop,
  String path,
  List<ValidationDiagnostic> diagnostics,
) {
  if (!hasNonEmptyProperty(node, prop)) return;

  final values = node.properties[prop];
  if (values == null) return;

  for (final value in values) {
    if (value is SchemaValueUrl) {
      if (value.value.startsWith('http://')) {
        diagnostics.add(ValidationDiagnostic(
          path: '$path.$prop',
          severity: Severity.warning,
          code: DiagnosticCode.invalidFieldValue,
          message: 'URL should use HTTPS instead of HTTP: ${value.value}',
        ));
      }
    }
  }
}
