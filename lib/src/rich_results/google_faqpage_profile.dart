import '../models/diagnostics.dart';
import '../models/schema_node.dart';
import '../models/schema_value.dart';
import 'google_common.dart';
import 'profile_interface.dart';

class GoogleFaqPageProfile implements Profile {
  @override
  String get name => 'google';

  @override
  String get version => '2026-04-01';

  @override
  String get sourceUrl =>
      'https://developers.google.com/search/docs/appearance/structured-data/faqpage';

  @override
  List<String> get supportedTypes => const ['FAQPage'];

  @override
  NodeProfileResult evaluateNode(
    SchemaNode node,
    List<ValidationDiagnostic> vocabDiagnostics,
  ) {
    const path = 'FAQPage';
    final diagnostics = <ValidationDiagnostic>[];
    final requiredMissing = <String>[];

    diagnostics.add(const ValidationDiagnostic(
      path: path,
      severity: Severity.info,
      code: DiagnosticCode.eligibilityRestricted,
      message:
          "FAQPage rich results eligibility is restricted to authoritative sites since 2024. Structural validation passed, but display depends on Google's site authority assessment.",
    ));

    final dMain = requireProperty(node, 'mainEntity', path);
    if (dMain != null) {
      requiredMissing.add('mainEntity');
      diagnostics.add(dMain);
    }

    final questions = getNestedNodes(node, 'mainEntity');
    if (questions.isEmpty && hasNonEmptyProperty(node, 'mainEntity')) {
      final values = node.properties['mainEntity'];
      if (values != null) {
        final hasAnyNode = values.any((v) => v is SchemaValueNode);
        if (!hasAnyNode) {
          diagnostics.add(const ValidationDiagnostic(
            path: '$path.mainEntity',
            severity: Severity.error,
            code: DiagnosticCode.invalidFieldValue,
            message: 'mainEntity must contain Question objects',
          ));
        }
      }
    }

    for (var i = 0; i < questions.length; i++) {
      final question = questions[i];
      final qPath =
          questions.length > 1 ? '$path.mainEntity[$i]' : '$path.mainEntity';

      final dQName = requireProperty(question, 'name', qPath);
      if (dQName != null) diagnostics.add(dQName);

      final dAnswer = requireProperty(question, 'acceptedAnswer', qPath);
      if (dAnswer != null) diagnostics.add(dAnswer);

      for (final answer in getNestedNodes(question, 'acceptedAnswer')) {
        final aPath = '$qPath.acceptedAnswer';
        final dAText = requireProperty(answer, 'text', aPath);
        if (dAText != null) diagnostics.add(dAText);
      }
    }

    final eligible = requiredMissing.isEmpty &&
        !diagnostics.any((d) =>
            d.severity == Severity.error &&
            d.code != DiagnosticCode.eligibilityRestricted);

    return NodeProfileResult(
      typeEligibility: TypeEligibility(
        schemaType: 'FAQPage',
        eligible: eligible,
        requiredMissing: requiredMissing,
        recommendedMissing: const [],
        fieldDiagnostics: diagnostics,
      ),
    );
  }
}
