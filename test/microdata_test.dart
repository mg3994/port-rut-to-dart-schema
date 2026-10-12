import 'package:schemaorg_validate/schemaorg_validate.dart';
import 'package:test/test.dart';

void main() {
  group('MicrodataExtractor', () {
    test('basic microdata product', () {
      const html = '''<html><body>
      <div itemscope itemtype="https://schema.org/Product">
        <span itemprop="name">Widget</span>
        <meta itemprop="sku" content="W123">
        <a itemprop="url" href="https://example.com/widget">Link</a>
      </div>
      </body></html>''';

      final out = MicrodataExtractor().extract(html);
      expect(out.nodes.length, equals(1));
      final node = out.nodes[0];
      expect(node.types, equals(['Product']));
      expect(node.sourceFormat, equals(SourceFormat.microdata));
      expect(node.properties['name'], equals([const SchemaValueText('Widget')]));
      expect(node.properties['sku'], equals([const SchemaValueText('W123')]));
      expect(node.properties['url'], equals([const SchemaValueUrl('https://example.com/widget')]));
    });

    test('nested itemscope', () {
      const html = '''<html><body>
      <div itemscope itemtype="https://schema.org/Product">
        <span itemprop="name">Widget</span>
        <div itemprop="offers" itemscope itemtype="https://schema.org/Offer">
          <span itemprop="priceCurrency">USD</span>
          <span itemprop="price">19.99</span>
        </div>
      </div>
      </body></html>''';

      final out = MicrodataExtractor().extract(html);
      expect(out.nodes.length, equals(1));
      final offer = (out.nodes[0].properties['offers']![0] as SchemaValueNode).node;
      expect(offer.types, equals(['Offer']));
      expect(offer.properties['priceCurrency'], equals([const SchemaValueText('USD')]));
    });

    test('itemref merging', () {
      const html = '''<html><body>
      <div itemscope itemtype="https://schema.org/Product" itemref="extra-details">
        <span itemprop="name">Widget</span>
      </div>
      <div id="extra-details">
        <span itemprop="sku">SKU123</span>
      </div>
      </body></html>''';

      final out = MicrodataExtractor().extract(html);
      expect(out.nodes[0].properties['sku'], equals([const SchemaValueText('SKU123')]));
    });

    test('time element with datetime attribute', () {
      const html = '''<html><body>
      <div itemscope itemtype="https://schema.org/Event">
        <span itemprop="name">Concert</span>
        <time itemprop="startDate" datetime="2024-06-15T20:00:00Z">June 15</time>
      </div>
      </body></html>''';

      final out = MicrodataExtractor().extract(html);
      expect(out.nodes[0].properties['startDate'], equals([const SchemaValueDateTime('2024-06-15T20:00:00Z')]));
    });

    test('space separated itemprop names', () {
      const html = '''<html><body>
      <div itemscope itemtype="https://schema.org/Product">
        <span itemprop="name title">Widget</span>
      </div>
      </body></html>''';

      final out = MicrodataExtractor().extract(html);
      expect(out.nodes[0].properties['name'], equals([const SchemaValueText('Widget')]));
      expect(out.nodes[0].properties['title'], equals([const SchemaValueText('Widget')]));
    });
  });
}
