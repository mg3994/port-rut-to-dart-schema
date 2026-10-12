import 'package:schemaorg_validate/schemaorg_validate.dart';
import 'package:test/test.dart';

void main() {
  group('JsonLdExtractor', () {
    test('line index positions', () {
      final idx = LineIndex('line1\nline2\nline3');
      var loc = idx.location(0);
      expect(loc.line, equals(1));
      expect(loc.column, equals(1));

      loc = idx.location(6);
      expect(loc.line, equals(2));
      expect(loc.column, equals(1));

      loc = idx.location(8);
      expect(loc.line, equals(2));
      expect(loc.column, equals(3));
    });

    test('find script offsets', () {
      const html = '<html><script type="application/ld+json">{"@type":"Product"}</script></html>';
      final offsets = findScriptByteOffsets(html);
      expect(offsets.length, equals(1));
      expect(html.substring(offsets[0]).startsWith('<script'), isTrue);
    });

    test('basic product', () {
      const html = '''<html><head><script type="application/ld+json">{
  "@context": "https://schema.org",
  "@type": "Product",
  "name": "Example Product",
  "url": "https://example.com/product"
}</script></head></html>''';

      final out = JsonLdExtractor().extract(html);
      expect(out.nodes.length, equals(1));
      expect(out.nodes[0].types, equals(['Product']));
      expect(out.nodes[0].sourceFormat, equals(SourceFormat.jsonLd));
      expect(out.nodes[0].properties['name'], equals([const SchemaValueText('Example Product')]));
      expect(out.nodes[0].properties['url'], equals([const SchemaValueUrl('https://example.com/product')]));
    });

    test('graph extraction', () {
      const html = '''<html><head><script type="application/ld+json">{
  "@context": "https://schema.org",
  "@graph": [
    {"@type": "Organization", "name": "Acme"},
    {"@type": "WebSite", "name": "Acme Site"}
  ]
}</script></head></html>''';

      final out = JsonLdExtractor().extract(html);
      expect(out.nodes.length, equals(2));
      expect(out.nodes[0].types, equals(['Organization']));
      expect(out.nodes[1].types, equals(['WebSite']));
    });

    test('array type', () {
      const html = '''<html><head><script type="application/ld+json">{
  "@context": "https://schema.org",
  "@type": ["Product", "IndividualProduct"],
  "name": "Widget"
}</script></head></html>''';

      final out = JsonLdExtractor().extract(html);
      expect(out.nodes[0].types, equals(['Product', 'IndividualProduct']));
    });

    test('nested object', () {
      const html = '''<html><head><script type="application/ld+json">{
  "@context": "https://schema.org",
  "@type": "Product",
  "name": "Widget",
  "offers": {
    "@type": "Offer",
    "price": 19.99,
    "priceCurrency": "USD"
  }
}</script></head></html>''';

      final out = JsonLdExtractor().extract(html);
      expect(out.nodes.length, equals(1));
      final offers = out.nodes[0].properties['offers']!;
      expect(offers.length, equals(1));
      final offerNode = (offers[0] as SchemaValueNode).node;
      expect(offerNode.types, equals(['Offer']));
      expect(offerNode.properties['price'], equals([const SchemaValueNumber(19.99)]));
      expect(offerNode.properties['priceCurrency'], equals([const SchemaValueText('USD')]));
    });

    test('id cross reference', () {
      const html = '''<html><head><script type="application/ld+json">{
  "@context": "https://schema.org",
  "@graph": [
    {"@type": "Product", "name": "Widget", "offers": {"@id": "#offer1"}},
    {"@id": "#offer1", "@type": "Offer", "price": 29.99}
  ]
}</script></head></html>''';

      final out = JsonLdExtractor().extract(html);
      expect(out.nodes.length, equals(2));
      final offers = out.nodes[0].properties['offers']!;
      final offerNode = (offers[0] as SchemaValueNode).node;
      expect(offerNode.types, equals(['Offer']));
      expect(offerNode.properties['price'], equals([const SchemaValueNumber(29.99)]));
    });

    test('circular id reference does not stack overflow', () {
      const html = '''<html><head><script type="application/ld+json">{
  "@context": "https://schema.org",
  "@graph": [
    {"@id": "#a", "@type": "Product", "name": "A", "isRelatedTo": {"@id": "#b"}},
    {"@id": "#b", "@type": "Article", "name": "B", "isRelatedTo": {"@id": "#a"}}
  ]
}</script></head></html>''';

      final out = JsonLdExtractor().extract(html);
      expect(out.nodes.length, equals(2));
    });

    test('self referencing id does not loop', () {
      const html = '''<html><head><script type="application/ld+json">{
  "@context": "https://schema.org",
  "@graph": [
    {"@id": "#self", "@type": "Product", "name": "Me", "isRelatedTo": {"@id": "#self"}}
  ]
}</script></head></html>''';

      final out = JsonLdExtractor().extract(html);
      expect(out.nodes.length, equals(1));
    });

    test('duplicate id first definition wins', () {
      const html = '''<html><head><script type="application/ld+json">{
  "@context": "https://schema.org",
  "@graph": [
    {"@type": "Product", "name": "P", "offers": {"@id": "#dup"}},
    {"@id": "#dup", "@type": "Offer", "price": 10.00, "priceCurrency": "USD"},
    {"@id": "#dup", "@type": "Offer", "price": 99.99, "priceCurrency": "EUR"}
  ]
}</script></head></html>''';

      final out = JsonLdExtractor().extract(html);
      expect(out.warnings.any((w) => w.code == WarningCode.duplicateId), isTrue);
      final offers = out.nodes[0].properties['offers']!;
      final offerNode = (offers[0] as SchemaValueNode).node;
      expect(offerNode.properties['price'], equals([const SchemaValueNumber(10.0)]));
      expect(offerNode.properties['priceCurrency'], equals([const SchemaValueText('USD')]));
    });

    test('type is number or empty array ignored', () {
      const html = '''<html><head><script type="application/ld+json">{
  "@context": "https://schema.org",
  "@type": 42,
  "name": "Widget"
}</script></head></html>''';

      final out = JsonLdExtractor().extract(html);
      expect(out.nodes.length, equals(1));
      expect(out.nodes[0].types, isEmpty);
      expect(out.warnings.any((w) => w.code == WarningCode.emptyType), isTrue);
    });

    test('multiple references to same id', () {
      const html = '''<html><head><script type="application/ld+json">{
  "@context": "https://schema.org",
  "@graph": [
    {
      "@type": "Product", "name": "Widget",
      "offers": {"@id": "#offer"},
      "makesOffer": {"@id": "#offer"},
      "hasOfferCatalog": {"@id": "#offer"}
    },
    {"@id": "#offer", "@type": "Offer", "price": 9.99}
  ]
}</script></head></html>''';

      final out = JsonLdExtractor().extract(html);
      expect(out.nodes.length, equals(2));
      for (final prop in ['offers', 'makesOffer', 'hasOfferCatalog']) {
        final val = out.nodes[0].properties[prop]![0];
        expect((val as SchemaValueNode).node.types, equals(['Offer']));
      }
    });
  });
}
