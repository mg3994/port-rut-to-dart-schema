import 'package:schemaorg_validate/schemaorg_validate.dart';
import 'package:test/test.dart';

void main() {
  group('SARIF 2.1.0 Exporter', () {
    test('rule id mapping completeness', () {
      for (final code in DiagnosticCode.values) {
        final id = ruleId(code);
        expect(id, isNotEmpty);
        expect(id.startsWith('SCHEMA') || id.startsWith('PROFILE'), isTrue);
      }
    });

    test('sarif level mapping', () {
      expect(sarifLevel(Severity.error), equals('error'));
      expect(sarifLevel(Severity.warning), equals('warning'));
      expect(sarifLevel(Severity.info), equals('note'));
    });

    test('build sarif empty result', () {
      final sarif = buildSarif([], null, 'test.html');
      expect(sarif['version'], equals('2.1.0'));
      expect((sarif['runs'] as List)[0]['results'], isEmpty);
    });

    test('build sarif with diagnostics', () {
      final vocab = [
        const ValidationDiagnostic(
          path: 'Product.name',
          severity: Severity.error,
          code: DiagnosticCode.unknownProperty,
          message: "Unknown property 'namee'",
        ),
      ];

      final sarif = buildSarif(vocab, null, 'index.html');
      final results = (sarif['runs'] as List)[0]['results'] as List;
      expect(results.length, equals(1));
      expect(results[0]['ruleId'], equals('SCHEMA002'));
      expect(results[0]['level'], equals('error'));
      expect(
        results[0]['locations'][0]['physicalLocation']['artifactLocation']['uri'],
        equals('index.html'),
      );
    });

    test('build sarif with source location', () {
      final vocab = [
        const ValidationDiagnostic(
          path: 'Product',
          severity: Severity.warning,
          code: DiagnosticCode.deprecatedType,
          message: 'Deprecated type',
          sourceLocation: SourceLocation(line: 15, column: 3, byteOffset: 200),
        ),
      ];

      final sarif = buildSarif(vocab, null, 'page.html');
      final results = (sarif['runs'] as List)[0]['results'] as List;
      final region = results[0]['locations'][0]['physicalLocation']['region'];
      expect(region['startLine'], equals(15));
      expect(region['startColumn'], equals(3));
    });
  });
}
