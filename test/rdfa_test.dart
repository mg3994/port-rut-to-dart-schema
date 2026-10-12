import 'package:schemaorg_validate/schemaorg_validate.dart';
import 'package:test/test.dart';

void main() {
  group('RdfaLiteExtractor', () {
    test('basic rdfa product', () {
      const html = '''<html><body>
      <div vocab="https://schema.org/" typeof="Product">
        <span property="name">Widget</span>
        <meta property="sku" content="SKU99">
      </div>
      </body></html>''';

      final out = RdfaLiteExtractor().extract(html);
      expect(out.nodes.length, equals(1));
      final node = out.nodes[0];
      expect(node.types, equals(['Product']));
      expect(node.sourceFormat, equals(SourceFormat.rdfaLite));
      expect(node.properties['name'], equals([const SchemaValueText('Widget')]));
      expect(node.properties['sku'], equals([const SchemaValueText('SKU99')]));
    });

    test('nested typeof with property', () {
      const html = '''<html><body>
      <div vocab="https://schema.org/" typeof="Product">
        <span property="name">Widget</span>
        <div property="offers" typeof="Offer">
          <span property="priceCurrency">USD</span>
        </div>
      </div>
      </body></html>''';

      final out = RdfaLiteExtractor().extract(html);
      expect(out.nodes.length, equals(1));
      final offers = out.nodes[0].properties['offers']!;
      final offerNode = (offers[0] as SchemaValueNode).node;
      expect(offerNode.types, equals(['Offer']));
      expect(offerNode.properties['priceCurrency'], equals([const SchemaValueText('USD')]));
    });

    test('prefix mapping resolution', () {
      const html = '''<html prefix="schema: https://schema.org/"><body>
      <div typeof="schema:Product">
        <span property="schema:name">Widget</span>
      </div>
      </body></html>''';

      final out = RdfaLiteExtractor().extract(html);
      expect(out.nodes[0].types, equals(['Product']));
      expect(out.nodes[0].properties['name'], equals([const SchemaValueText('Widget')]));
    });

    test('data element with value attribute', () {
      const html = '''<html><body>
      <div vocab="https://schema.org/" typeof="Product">
        <data property="sku" value="12345">Product SKU</data>
      </div>
      </body></html>''';

      final out = RdfaLiteExtractor().extract(html);
      expect(out.nodes[0].properties['sku'], equals([const SchemaValueText('12345')]));
    });

    test('empty typeof warns', () {
      const html = '''<html><body>
      <div vocab="https://schema.org/" typeof="">
        <span property="name">Something</span>
      </div>
      </body></html>''';

      final out = RdfaLiteExtractor().extract(html);
      expect(out.warnings.any((w) => w.code == WarningCode.emptyType), isTrue);
    });
  });
}
