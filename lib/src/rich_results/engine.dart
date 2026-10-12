import '../models/diagnostics.dart';
import '../parser/html_extractor.dart';
import '../vocabulary/vocabulary.dart';
import 'profile_interface.dart';

ProfileResult evaluateGraph(
  Profile profile,
  StructuredDataGraph graph,
  List<ValidationDiagnostic> vocabDiagnostics,
) {
  final typeResults = <TypeEligibility>[];
  final allDiagnostics = <ValidationDiagnostic>[];

  for (final node in graph.nodes) {
    final dominated = node.types.any((t) {
      return profile.supportedTypes.any((supported) {
        return t == supported || isSubtype(t, supported);
      });
    });

    if (!dominated) continue;

    final result = profile.evaluateNode(node, vocabDiagnostics);
    allDiagnostics.addAll(result.typeEligibility.fieldDiagnostics);
    typeResults.add(result.typeEligibility);
  }

  final eligibility = aggregateEligibility(typeResults, allDiagnostics);

  return ProfileResult(
    eligibility: eligibility,
    typeResults: typeResults,
    diagnostics: allDiagnostics,
  );
}

Eligibility aggregateEligibility(
  List<TypeEligibility> typeResults,
  List<ValidationDiagnostic> diagnostics,
) {
  if (typeResults.isEmpty) {
    return Eligibility.notEligible;
  }

  final hasRestricted = diagnostics
      .any((d) => d.code == DiagnosticCode.eligibilityRestricted);

  final allEligible = typeResults.every((r) => r.eligible);
  final hasWarnings = diagnostics.isNotEmpty;

  if (hasRestricted) {
    return Eligibility.restricted;
  } else if (allEligible && !hasWarnings) {
    return Eligibility.eligible;
  } else if (allEligible) {
    return Eligibility.warningsOnly;
  } else {
    return Eligibility.notEligible;
  }
}
