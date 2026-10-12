import 'source_location.dart';

/// Machine-readable warning codes for extraction issues.
enum WarningCode {
  malformedJsonLd('malformed-json-ld'),
  malformedMicrodata('malformed-microdata'),
  malformedRdfa('malformed-rdfa'),
  unresolvableReference('unresolvable-reference'),
  emptyType('empty-type'),
  duplicateId('duplicate-id'),
  extractorFailed('extractor-failed');

  final String codeString;
  const WarningCode(this.codeString);

  @override
  String toString() => codeString;
}

/// A non-fatal warning produced during extraction.
class ExtractionWarning {
  final String message;
  final SourceLocation? sourceLocation;
  final WarningCode code;

  const ExtractionWarning({
    required this.message,
    this.sourceLocation,
    required this.code,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExtractionWarning &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          sourceLocation == other.sourceLocation &&
          code == other.code;

  @override
  int get hashCode => Object.hash(message, sourceLocation, code);

  @override
  String toString() =>
      'ExtractionWarning($code, message: "$message", location: $sourceLocation)';
}

/// Fatal extraction exception.
class ExtractionException implements Exception {
  final String message;
  const ExtractionException(this.message);

  @override
  String toString() => 'ExtractionException: $message';
}
