import 'package:schemaorg_validate/schemaorg_validate.dart';
import 'package:test/test.dart';

void main() {
  group('Models & Data Structures', () {
    test('SourceFormat toString', () {
      expect(SourceFormat.jsonLd.toString(), equals('JSON-LD'));
      expect(SourceFormat.microdata.toString(), equals('Microdata'));
      expect(SourceFormat.rdfaLite.toString(), equals('RDFa Lite'));
    });

    test('SourceLocation equality and serialization', () {
      const loc1 = SourceLocation(line: 10, column: 5, byteOffset: 120);
      const loc2 = SourceLocation(line: 10, column: 5, byteOffset: 120);
      const loc3 = SourceLocation(line: 12, column: 1, byteOffset: 150);

      expect(loc1, equals(loc2));
      expect(loc1.hashCode, equals(loc2.hashCode));
      expect(loc1, isNot(equals(loc3)));

      final json = loc1.toJson();
      expect(json, equals({'line': 10, 'column': 5, 'byte_offset': 120}));

      final restored = SourceLocation.fromJson(json);
      expect(restored, equals(loc1));
      expect(loc1.toString(), contains('line: 10'));
    });

    test('SchemaValue variants toString and equality', () {
      const text1 = SchemaValueText('Widget');
      const text2 = SchemaValueText('Widget');
      const url = SchemaValueUrl('https://example.com');
      const numVal = SchemaValueNumber(19.99);
      const boolVal = SchemaValueBoolean(true);
      const dateVal = SchemaValueDateTime('2024-01-01');

      expect(text1, equals(text2));
      expect(text1.toString(), equals('Widget'));
      expect(url.toString(), equals('https://example.com'));
      expect(numVal.toString(), equals('19.99'));
      expect(boolVal.toString(), equals('true'));
      expect(dateVal.toString(), equals('2024-01-01'));
    });

    test('SchemaNode id extraction and equality', () {
      final node1 = SchemaNode(
        types: ['Product'],
        properties: {
          '@id': [const SchemaValueText('#prod1')],
          'name': [const SchemaValueText('Widget')],
        },
        sourceFormat: SourceFormat.jsonLd,
      );

      final node2 = SchemaNode(
        types: ['Product'],
        properties: {
          '@id': [const SchemaValueText('#prod1')],
          'name': [const SchemaValueText('Widget')],
        },
        sourceFormat: SourceFormat.jsonLd,
      );

      expect(node1.id, equals('#prod1'));
      expect(node1, equals(node2));
      expect(node1.hashCode, equals(node2.hashCode));
      expect(node1.toString(), contains('types: [Product]'));
    });

    test('Severity ranks and comparison operators', () {
      expect(Severity.error > Severity.warning, isTrue);
      expect(Severity.warning > Severity.info, isTrue);
      expect(Severity.info < Severity.warning, isTrue);
      expect(Severity.error >= Severity.error, isTrue);
      expect(Severity.warning <= Severity.error, isTrue);
      expect(Severity.error.compareTo(Severity.warning), greaterThan(0));

      expect(Severity.error.toString(), equals('error'));
      expect(Severity.warning.toString(), equals('warning'));
      expect(Severity.info.toString(), equals('info'));
    });

    test('DiagnosticCode string codes', () {
      expect(DiagnosticCode.unknownType.toString(), equals('unknown-type'));
      expect(DiagnosticCode.requiredFieldMissing.toString(), equals('required-field-missing'));
    });

    test('WarningCode string codes', () {
      expect(WarningCode.malformedJsonLd.toString(), equals('malformed-json-ld'));
      expect(WarningCode.duplicateId.toString(), equals('duplicate-id'));
    });
  });
}
