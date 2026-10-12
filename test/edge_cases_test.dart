import 'package:schemaorg_validate/schemaorg_validate.dart';
import 'package:test/test.dart';

void main() {
  group('Edge Cases & Robustness', () {
    test('JSON-LD with malformed JSON produces warning and does not crash', () {
      const html = '''<html><head>
      <script type="application/ld+json">{ "invalid": json content... }</script>
      </head></html>''';

      final out = JsonLdExtractor().extract(html);
      expect(out.nodes, isEmpty);
      expect(out.warnings.length, equals(1));
      expect(out.warnings[0].code, equals(WarningCode.malformedJsonLd));
      expect(out.warnings[0].message, contains('failed to parse JSON-LD'));
    });

    test('JSON-LD with Unicode and emoji text preserved accurately', () {
      const html = '''<html><head>
      <script type="application/ld+json">{
        "@context": "https://schema.org",
        "@type": "Product",
        "name": "Gerät für Ökologie 🌿⚡",
        "description": "日本語の説明文"
      }</script>
      </head></html>''';

      final out = JsonLdExtractor().extract(html);
      expect(out.nodes.length, equals(1));
      expect(out.nodes[0].properties['name'], equals([const SchemaValueText('Gerät für Ökologie 🌿⚡')]));
      expect(out.nodes[0].properties['description'], equals([const SchemaValueText('日本語の説明文')]));
    });

    test('JSON-LD nesting exceeding max depth produces warning', () {
      var json = '{"@context":"https://schema.org","@type":"Thing","name":"L0"';
      for (var i = 1; i <= 22; i++) {
        json += ',"p$i":{"@type":"Thing","name":"L$i"';
      }
      for (var i = 0; i <= 22; i++) {
        json += '}';
      }

      final html = '<html><head><script type="application/ld+json">$json</script></head></html>';

      final out = JsonLdExtractor().extract(html);
      expect(out.warnings.any((w) => w.message.contains('depth')), isTrue);
    });

    test('ISO 8601 date parsing edge cases with timezone offsets', () {
      expect(isIsoDatetime('2024-06-15'), isTrue);
      expect(isIsoDatetime('2024-06-15T10:30:00Z'), isTrue);
      expect(isIsoDatetime('2024-06-15T10:30:00+02:00'), isTrue);
      expect(isIsoDatetime('2024-06-15T10:30:00-05:00'), isTrue);
      expect(isIsoDatetime('2024-13-15'), isFalse); // Month 13 invalid
      expect(isIsoDatetime('2024-00-15'), isFalse); // Month 00 invalid
      expect(isIsoDatetime('2024-06-32'), isFalse); // Day 32 invalid
      expect(isIsoDatetime('not a date'), isFalse);
    });

    test('Microdata with multiple itemtypes on single element', () {
      const html = '''<html><body>
      <div itemscope itemtype="https://schema.org/Product https://schema.org/IndividualProduct">
        <span itemprop="name">Gadget</span>
      </div>
      </body></html>''';

      final out = MicrodataExtractor().extract(html);
      expect(out.nodes.length, equals(1));
      expect(out.nodes[0].types, equals(['Product', 'IndividualProduct']));
    });

    test('RDFa Lite with empty vocab resets vocabulary context', () {
      const html = '''<html vocab="https://schema.org/"><body>
      <div typeof="Product">
        <span property="name">Outer Product</span>
        <div vocab="">
          <div typeof="CustomThing">
            <span property="label">Inner Thing</span>
          </div>
        </div>
      </div>
      </body></html>''';

      final out = RdfaLiteExtractor().extract(html);
      expect(out.nodes.any((n) => n.types.contains('Product')), isTrue);
    });

    test('Validation of multi-type nodes in Product profile', () {
      const html = '''<script type="application/ld+json">{
        "@context": "https://schema.org",
        "@type": ["Product", "IndividualProduct"],
        "name": "Specialized Widget",
        "image": "https://example.com/widget.jpg"
      }</script>''';

      final graph = extractAll(html);
      final vocab = validate(graph);
      final reg = ProfileRegistry.withGoogle();
      final profileResult = reg.evaluate('google', graph, vocab.diagnostics);

      expect(profileResult.typeResults.length, equals(1));
      expect(profileResult.typeResults[0].schemaType, equals('Product'));
      expect(profileResult.typeResults[0].eligible, isTrue);
    });

    test('Levenshtein distance handles uppercase and lowercase variations', () {
      expect(suggestSimilar('produc', ['Product']), equals('Product'));
      expect(suggestSimilar('PRODUC', ['Product']), equals('Product'));
    });
  });
}
