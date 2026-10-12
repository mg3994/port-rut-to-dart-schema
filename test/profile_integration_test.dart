import 'package:schemaorg_validate/schemaorg_validate.dart';
import 'package:test/test.dart';

ProfileResult fullPipeline(String html, String profile) {
  final graph = extractAll(html);
  final vocab = validate(graph);
  final reg = ProfileRegistry.withGoogle();
  return reg.evaluate(profile, graph, vocab.diagnostics);
}

void main() {
  group('Profile Integration', () {
    test('microdata product eligible', () {
      const html = '''<html><body>
          <div itemscope itemtype="https://schema.org/Product">
              <span itemprop="name">Widget</span>
              <img itemprop="image" src="https://example.com/widget.jpg">
              <meta itemprop="description" content="A great widget">
              <meta itemprop="sku" content="W123">
              <meta itemprop="gtin" content="012345678">
              <div itemprop="brand" itemscope itemtype="https://schema.org/Brand">
                  <span itemprop="name">Acme</span>
              </div>
          </div>
      </body></html>''';

      final r = fullPipeline(html, 'google');
      expect(r.typeResults.any((t) => t.schemaType == 'Product' && t.eligible), isTrue);
    });

    test('rdfa article eligible', () {
      const html = '''<html><body>
          <div vocab="https://schema.org/" typeof="Article">
              <h1 property="headline">Test Article</h1>
              <img property="image" src="https://example.com/a.jpg">
              <time property="datePublished" datetime="2024-01-15">Jan 15</time>
              <div property="author" typeof="Person">
                  <span property="name">Alice</span>
              </div>
          </div>
      </body></html>''';

      final r = fullPipeline(html, 'google');
      expect(r.typeResults.any((t) => t.schemaType == 'Article' && t.eligible), isTrue);
    });

    test('jsonld and microdata mixed', () {
      const html = '''<html><head>
          <script type="application/ld+json">{
              "@context": "https://schema.org",
              "@type": "Product",
              "name": "Widget"
          }</script>
      </head><body>
          <div itemscope itemtype="https://schema.org/Event">
              <span itemprop="name">Concert</span>
              <time itemprop="startDate" datetime="2024-06-01T20:00">June 1</time>
              <div itemprop="location" itemscope itemtype="https://schema.org/Place">
                  <span itemprop="name">Venue</span>
                  <span itemprop="address">123 Main St</span>
              </div>
          </div>
      </body></html>''';

      final r = fullPipeline(html, 'google');
      expect(r.typeResults.length, greaterThanOrEqualTo(2));
      expect(r.typeResults.any((t) => t.schemaType == 'Product'), isTrue);
      expect(r.typeResults.any((t) => t.schemaType == 'Event'), isTrue);
    });

    test('vocab errors dont block profile', () {
      const html = '''<html><head>
          <script type="application/ld+json">{
              "@context": "https://schema.org",
              "@type": "Product",
              "name": "Widget",
              "fakeProperty": "value"
          }</script>
      </head></html>''';

      final graph = extractAll(html);
      final vocab = validate(graph);
      expect(vocab.hasErrors, isTrue);

      final reg = ProfileRegistry.withGoogle();
      final r = reg.evaluate('google', graph, vocab.diagnostics);
      expect(r.typeResults.any((t) => t.schemaType == 'Product' && t.eligible), isTrue);
    });

    test('empty html no types', () {
      final r = fullPipeline('<html></html>', 'google');
      expect(r.eligibility, equals(Eligibility.notEligible));
      expect(r.typeResults, isEmpty);
    });
  });
}
