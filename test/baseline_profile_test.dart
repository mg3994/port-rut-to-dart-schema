import 'package:schemaorg_validate/schemaorg_validate.dart';
import 'package:test/test.dart';

void main() {
  group('BaselineProfile', () {
    test('baseline profile name and version', () {
      final profile = BaselineProfile();
      expect(profile.name, equals('baseline'));
      expect(profile.version, isNotEmpty);
      expect(profile.sourceUrl, contains('schema.org'));
      expect(profile.supportedTypes, equals(['Thing']));
    });

    test('baseline profile evaluates thing with name, image, description', () {
      final node = SchemaNode(
        types: ['Thing'],
        properties: {
          'name': [const SchemaValueText('Test Thing')],
          'image': [const SchemaValueUrl('https://example.com/thing.jpg')],
          'description': [const SchemaValueText('A test thing')],
        },
        sourceFormat: SourceFormat.jsonLd,
      );

      final profile = BaselineProfile();
      final res = profile.evaluateNode(node, []);

      expect(res.typeEligibility.eligible, isTrue);
      expect(res.typeEligibility.recommendedMissing, isEmpty);
    });

    test('baseline profile warns for missing name and HTTP url', () {
      final node = SchemaNode(
        types: ['Thing'],
        properties: {
          'url': [const SchemaValueUrl('http://example.com/thing')],
        },
        sourceFormat: SourceFormat.jsonLd,
      );

      final profile = BaselineProfile();
      final res = profile.evaluateNode(node, []);

      expect(res.typeEligibility.recommendedMissing, contains('name/headline'));
      expect(res.typeEligibility.recommendedMissing, contains('image'));
      expect(res.typeEligibility.recommendedMissing, contains('description'));
      expect(
        res.typeEligibility.fieldDiagnostics.any(
          (d) => d.message.contains('HTTPS instead of HTTP'),
        ),
        isTrue,
      );
    });
  });
}
