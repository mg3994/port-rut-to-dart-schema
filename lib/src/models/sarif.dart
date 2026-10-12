import 'diagnostics.dart';

const String sarifSchema =
    'https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json';

String ruleId(DiagnosticCode code) {
  switch (code) {
    case DiagnosticCode.unknownType:
      return 'SCHEMA001';
    case DiagnosticCode.unknownProperty:
      return 'SCHEMA002';
    case DiagnosticCode.invalidValueType:
      return 'SCHEMA003';
    case DiagnosticCode.deprecatedType:
      return 'SCHEMA004';
    case DiagnosticCode.deprecatedProperty:
      return 'SCHEMA005';
    case DiagnosticCode.propertyNotForType:
      return 'SCHEMA006';
    case DiagnosticCode.pendingType:
      return 'SCHEMA007';
    case DiagnosticCode.pendingProperty:
      return 'SCHEMA008';
    case DiagnosticCode.expectedUrlGotText:
      return 'SCHEMA009';
    case DiagnosticCode.expectedTextGotNode:
      return 'SCHEMA010';
    case DiagnosticCode.invalidEnumValue:
      return 'SCHEMA011';
    case DiagnosticCode.invalidBoolean:
      return 'SCHEMA012';
    case DiagnosticCode.invalidNumber:
      return 'SCHEMA013';
    case DiagnosticCode.requiredFieldMissing:
      return 'PROFILE001';
    case DiagnosticCode.recommendedFieldMissing:
      return 'PROFILE002';
    case DiagnosticCode.nestedRequiredFieldMissing:
      return 'PROFILE003';
    case DiagnosticCode.invalidFieldValue:
      return 'PROFILE004';
    case DiagnosticCode.eligibilityRestricted:
      return 'PROFILE005';
  }
}

String sarifLevel(Severity severity) {
  switch (severity) {
    case Severity.error:
      return 'error';
    case Severity.warning:
      return 'warning';
    case Severity.info:
      return 'note';
  }
}

Map<String, dynamic> buildRule(DiagnosticCode code) {
  final id = ruleId(code);
  final (String name, String desc, String level) = switch (code) {
    DiagnosticCode.unknownType => ('UnknownType', 'Unknown Schema.org type', 'error'),
    DiagnosticCode.unknownProperty => ('UnknownProperty', 'Unknown Schema.org property', 'error'),
    DiagnosticCode.invalidValueType => ('InvalidValueType', 'Value type mismatch', 'error'),
    DiagnosticCode.deprecatedType => ('DeprecatedType', 'Type retired from Schema.org', 'warning'),
    DiagnosticCode.deprecatedProperty => ('DeprecatedProperty', 'Property superseded', 'warning'),
    DiagnosticCode.propertyNotForType => ('PropertyNotForType', 'Property not valid for this type', 'warning'),
    DiagnosticCode.pendingType => ('PendingType', 'Type in pending vocabulary', 'note'),
    DiagnosticCode.pendingProperty => ('PendingProperty', 'Property in pending vocabulary', 'note'),
    DiagnosticCode.expectedUrlGotText => ('ExpectedUrlGotText', 'Expected URL value', 'warning'),
    DiagnosticCode.expectedTextGotNode => ('ExpectedTextGotNode', 'Expected text, got nested object', 'error'),
    DiagnosticCode.invalidEnumValue => ('InvalidEnumValue', 'Invalid enumeration member', 'error'),
    DiagnosticCode.invalidBoolean => ('InvalidBoolean', 'Expected boolean value', 'warning'),
    DiagnosticCode.invalidNumber => ('InvalidNumber', 'Expected numeric value', 'warning'),
    DiagnosticCode.requiredFieldMissing => ('RequiredFieldMissing', 'Required field for rich results', 'error'),
    DiagnosticCode.recommendedFieldMissing => ('RecommendedFieldMissing', 'Recommended field for rich results', 'warning'),
    DiagnosticCode.nestedRequiredFieldMissing => ('NestedRequiredFieldMissing', 'Missing field in nested requirement', 'error'),
    DiagnosticCode.invalidFieldValue => ('InvalidFieldValue', 'Invalid field value for profile', 'error'),
    DiagnosticCode.eligibilityRestricted => ('EligibilityRestricted', 'Rich result eligibility restricted', 'note'),
  };

  return <String, dynamic>{
    'id': id,
    'name': name,
    'shortDescription': <String, dynamic>{'text': desc},
    'defaultConfiguration': <String, dynamic>{'level': level},
  };
}

Map<String, dynamic> diagnosticToResult(
  ValidationDiagnostic diag,
  String sourceUri,
) {
  final physicalLocation = <String, dynamic>{
    'artifactLocation': <String, dynamic>{'uri': sourceUri},
  };

  if (diag.sourceLocation != null) {
    physicalLocation['region'] = <String, dynamic>{
      'startLine': diag.sourceLocation!.line,
      'startColumn': diag.sourceLocation!.column,
    };
  }

  final location = <String, dynamic>{
    'physicalLocation': physicalLocation,
  };

  if (diag.path.isNotEmpty) {
    location['logicalLocations'] = <Map<String, dynamic>>[
      <String, dynamic>{
        'fullyQualifiedName': diag.path,
        'kind': 'object',
      }
    ];
  }

  return <String, dynamic>{
    'ruleId': ruleId(diag.code),
    'level': sarifLevel(diag.severity),
    'message': <String, dynamic>{'text': diag.message},
    'locations': <dynamic>[location],
  };
}

Map<String, dynamic> buildSarif(
  List<ValidationDiagnostic> vocabDiagnostics,
  List<ValidationDiagnostic>? profileDiagnostics,
  String sourceUri, {
  String version = '1.0.0',
}) {
  final seenCodes = <DiagnosticCode>{};
  final rules = <Map<String, dynamic>>[];
  final results = <Map<String, dynamic>>[];

  for (final diag in vocabDiagnostics) {
    if (seenCodes.add(diag.code)) {
      rules.add(buildRule(diag.code));
    }
    results.add(diagnosticToResult(diag, sourceUri));
  }

  if (profileDiagnostics != null) {
    for (final diag in profileDiagnostics) {
      if (seenCodes.add(diag.code)) {
        rules.add(buildRule(diag.code));
      }
      results.add(diagnosticToResult(diag, sourceUri));
    }
  }

  return <String, dynamic>{
    '\$schema': sarifSchema,
    'version': '2.1.0',
    'runs': <dynamic>[
      <String, dynamic>{
        'tool': <String, dynamic>{
          'driver': <String, dynamic>{
            'name': 'schemaorg-validate',
            'version': version,
            'informationUri': 'https://github.com/mitrovicsinisaa/schemaorg-rs',
            'rules': rules,
          },
        },
        'results': results,
        'invocations': <dynamic>[
          <String, dynamic>{
            'executionSuccessful': true,
            'toolConfigurationNotifications': <dynamic>[],
          }
        ],
      }
    ],
  };
}
