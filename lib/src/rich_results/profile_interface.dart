import '../models/diagnostics.dart';
import '../models/schema_node.dart';

enum Eligibility {
  eligible,
  warningsOnly,
  notEligible,
  restricted;

  @override
  String toString() {
    switch (this) {
      case Eligibility.eligible:
        return 'Eligible';
      case Eligibility.warningsOnly:
        return 'WarningsOnly';
      case Eligibility.notEligible:
        return 'NotEligible';
      case Eligibility.restricted:
        return 'Restricted';
    }
  }
}

class TypeEligibility {
  final String schemaType;
  final bool eligible;
  final List<String> requiredMissing;
  final List<String> recommendedMissing;
  final List<ValidationDiagnostic> fieldDiagnostics;

  TypeEligibility({
    required this.schemaType,
    required this.eligible,
    required this.requiredMissing,
    required this.recommendedMissing,
    required this.fieldDiagnostics,
  });
}

class NodeProfileResult {
  final TypeEligibility typeEligibility;

  NodeProfileResult({required this.typeEligibility});
}

class ProfileResult {
  final Eligibility eligibility;
  final List<TypeEligibility> typeResults;
  final List<ValidationDiagnostic> diagnostics;

  ProfileResult({
    required this.eligibility,
    required this.typeResults,
    required this.diagnostics,
  });
}

abstract class Profile {
  String get name;
  String get version;
  String get sourceUrl;
  List<String> get supportedTypes;

  NodeProfileResult evaluateNode(
    SchemaNode node,
    List<ValidationDiagnostic> vocabDiagnostics,
  );
}

class ProfileException implements Exception {
  final String message;
  ProfileException(this.message);

  @override
  String toString() => 'ProfileException: $message';
}
