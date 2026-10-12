import 'package:schemaorg_validate/schemaorg_validate.dart';
import 'package:test/test.dart';

const productJsonLd = '''<html><head>
<script type="application/ld+json">{
  "@context": "https://schema.org",
  "@type": "Product",
  "name": "Widget",
  "description": "A great widget",
  "url": "https://example.com/widget"
}</script>
</head></html>''';

const productMicrodata = '''<html><body>
<div itemscope itemtype="https://schema.org/Product">
  <span itemprop="name">Widget</span>
  <span itemprop="description">A great widget</span>
  <a itemprop="url" href="https://example.com/widget">Widget</a>
</div>
</body></html>''';

const productRdfa = '''<html><body>
<div vocab="https://schema.org/" typeof="Product">
  <span property="name">Widget</span>
  <span property="description">A great widget</span>
  <a property="url" href="https://example.com/widget">Widget</a>
</div>
</body></html>''';

void main() {
  group('Cross-format extraction integration', () {
    test('cross format product types', () {
      final jld = JsonLdExtractor().extract(productJsonLd).nodes.first;
      final md = MicrodataExtractor().extract(productMicrodata).nodes.first;
      final rdfa = RdfaLiteExtractor().extract(productRdfa).nodes.first;

      expect(jld.types, equals(['Product']));
      expect(md.types, equals(['Product']));
      expect(rdfa.types, equals(['Product']));
    });

    test('cross format product name', () {
      final jld = JsonLdExtractor().extract(productJsonLd).nodes.first;
      final md = MicrodataExtractor().extract(productMicrodata).nodes.first;
      final rdfa = RdfaLiteExtractor().extract(productRdfa).nodes.first;

      const expected = [SchemaValueText('Widget')];
      expect(jld.properties['name'], equals(expected));
      expect(md.properties['name'], equals(expected));
      expect(rdfa.properties['name'], equals(expected));
    });

    test('cross format product url', () {
      final jld = JsonLdExtractor().extract(productJsonLd).nodes.first;
      final md = MicrodataExtractor().extract(productMicrodata).nodes.first;
      final rdfa = RdfaLiteExtractor().extract(productRdfa).nodes.first;

      const expected = [SchemaValueUrl('https://example.com/widget')];
      expect(jld.properties['url'], equals(expected));
      expect(md.properties['url'], equals(expected));
      expect(rdfa.properties['url'], equals(expected));
    });

    test('cross format source format differs', () {
      final jld = JsonLdExtractor().extract(productJsonLd).nodes.first;
      final md = MicrodataExtractor().extract(productMicrodata).nodes.first;
      final rdfa = RdfaLiteExtractor().extract(productRdfa).nodes.first;

      expect(jld.sourceFormat, equals(SourceFormat.jsonLd));
      expect(md.sourceFormat, equals(SourceFormat.microdata));
      expect(rdfa.sourceFormat, equals(SourceFormat.rdfaLite));
    });

    test('extractAll multi-format document', () {
      const html = '''<html><head>
      <script type="application/ld+json">{
        "@context": "https://schema.org",
        "@type": "Product",
        "name": "JSON-LD Widget"
      }</script>
      </head><body>
      <div itemscope itemtype="https://schema.org/Article">
        <span itemprop="name">Microdata Article</span>
      </div>
      </body></html>''';

      final graph = extractAll(html);
      expect(graph.nodes.length, equals(2));
      expect(graph.nodes[0].types, equals(['Product']));
      expect(graph.nodes[1].types, equals(['Article']));
    });
  });
}
