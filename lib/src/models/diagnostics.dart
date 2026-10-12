import 'source_location.dart';

/// Severity level for validation diagnostics.
enum Severity implements Comparable<Severity> {
  info(0),
  warning(1),
  error(2);

  final int rank;
  const Severity(this.rank);

  @override
  int compareTo(Severity other) => rank.compareTo(other.rank);

  bool operator >(Severity other) => rank > other.rank;
  bool operator >=(Severity other) => rank >= other.rank;
  bool operator <(Severity other) => rank < other.rank;
  bool operator <=(Severity other) => rank <= other.rank;

  @override
  String toString() {
    switch (this) {
      case Severity.error:
        return 'error';
      case Severity.warning:
        return 'warning';
      case Severity.info:
        return 'info';
    }
  }
}

/// Machine-readable diagnostic codes.
enum DiagnosticCode {
  // Type-level
  unknownType('unknown-type'),
  deprecatedType('deprecated-type'),
  pendingType('pending-type'),

  // Property-level
  unknownProperty('unknown-property'),
  propertyNotForType('property-not-for-type'),
  deprecatedProperty('deprecated-property'),
  pendingProperty('pending-property'),

  // Value-level
  invalidValueType('invalid-value-type'),
  expectedUrlGotText('expected-url-got-text'),
  expectedTextGotNode('expected-text-got-node'),
  invalidEnumValue('invalid-enum-value'),
  invalidBoolean('invalid-boolean'),
  invalidNumber('invalid-number'),

  // Profile-level
  requiredFieldMissing('required-field-missing'),
  recommendedFieldMissing('recommended-field-missing'),
  nestedRequiredFieldMissing('nested-required-field-missing'),
  invalidFieldValue('invalid-field-value'),
  eligibilityRestricted('eligibility-restricted');

  final String codeString;
  const DiagnosticCode(this.codeString);

  @override
  String toString() => codeString;
}

/// A single validation diagnostic (error, warning, or informational).
class ValidationDiagnostic {
  /// JSON-path-like location in the structured data graph.
  final String path;

  /// Severity level.
  final Severity severity;

  /// Machine-readable diagnostic code.
  final DiagnosticCode code;

  /// Human-readable message describing the issue.
  final String message;

  /// Location in the original HTML, if available.
  final SourceLocation? sourceLocation;

  const ValidationDiagnostic({
    required this.path,
    required this.severity,
    required this.code,
    required this.message,
    this.sourceLocation,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ValidationDiagnostic &&
          runtimeType == other.runtimeType &&
          path == other.path &&
          severity == other.severity &&
          code == other.code &&
          message == other.message &&
          sourceLocation == other.sourceLocation;

  @override
  int get hashCode =>
      Object.hash(path, severity, code, message, sourceLocation);

  @override
  String toString() =>
      'ValidationDiagnostic($severity, $code, path: "$path", message: "$message")';
}
