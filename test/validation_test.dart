import 'package:schemaorg_validate/schemaorg_validate.dart';
import 'package:test/test.dart';

void main() {
  group('Validation Integration', () {
    test('valid product no errors', () {
      const html = '''<script type="application/ld+json">{
        "@context": "https://schema.org",
        "@type": "Product",
        "name": "Test Widget",
        "description": "A test product",
        "offers": {
            "@type": "Offer",
            "price": "10.00",
            "priceCurrency": "EUR"
        }
      }</script>''';

      final graph = extractAll(html);
      final result = validate(graph);
      expect(result.hasErrors, isFalse, reason: 'Valid product should have no errors');
    });

    test('valid article no errors', () {
      const html = '''<script type="application/ld+json">{
        "@context": "https://schema.org",
        "@type": "Article",
        "headline": "Test Article",
        "author": {
            "@type": "Person",
            "name": "John Doe"
        }
      }</script>''';

      final graph = extractAll(html);
      final result = validate(graph);
      expect(result.hasErrors, isFalse);
    });

    test('valid event no errors', () {
      const html = '''<script type="application/ld+json">{
        "@context": "https://schema.org",
        "@type": "Event",
        "name": "Test Event",
        "startDate": "2024-06-15T19:00:00",
        "location": {
            "@type": "Place",
            "name": "Event Venue"
        }
      }</script>''';

      final graph = extractAll(html);
      final result = validate(graph);
      expect(result.hasErrors, isFalse);
    });

    test('typo in type reports error', () {
      const html = '''<script type="application/ld+json">{
        "@context": "https://schema.org",
        "@type": "Produc",
        "name": "Test"
      }</script>''';

      final graph = extractAll(html);
      final result = validate(graph);
      expect(result.hasErrors, isTrue);
      final unknown = result.errors.firstWhere((d) => d.code == DiagnosticCode.unknownType);
      expect(unknown.message, contains('Produc'));
      expect(unknown.message, contains('Product'));
    });

    test('completely invalid type', () {
      const html = '''<script type="application/ld+json">{
        "@context": "https://schema.org",
        "@type": "XYZNotAType123",
        "name": "Test"
      }</script>''';

      final graph = extractAll(html);
      final result = validate(graph);
      expect(result.errors.any((d) => d.code == DiagnosticCode.unknownType), isTrue);
    });

    test('typo in property reports error', () {
      const html = '''<script type="application/ld+json">{
        "@context": "https://schema.org",
        "@type": "Product",
        "namee": "Test"
      }</script>''';

      final graph = extractAll(html);
      final result = validate(graph);
      expect(result.hasErrors, isTrue);
      final unknown = result.errors.firstWhere((d) => d.code == DiagnosticCode.unknownProperty);
      expect(unknown.message, contains('namee'));
      expect(unknown.message, contains('name'));
    });

    test('property wrong domain', () {
      const html = '''<script type="application/ld+json">{
        "@context": "https://schema.org",
        "@type": "Product",
        "name": "Widget",
        "recipeCategory": "Main Course"
      }</script>''';

      final graph = extractAll(html);
      final result = validate(graph);
      expect(result.warnings.any((d) => d.code == DiagnosticCode.propertyNotForType), isTrue);
    });

    test('superseded property warns', () {
      const html = '''<script type="application/ld+json">{
        "@context": "https://schema.org",
        "@type": "TVSeries",
        "name": "Test Series",
        "episodes": {
            "@type": "Episode",
            "name": "Pilot"
        }
      }</script>''';

      final graph = extractAll(html);
      final result = validate(graph);
      expect(result.warnings.any((d) => d.code == DiagnosticCode.deprecatedProperty), isTrue);
    });

    test('nested node wrong type', () {
      const html = '''<script type="application/ld+json">{
        "@context": "https://schema.org",
        "@type": "Product",
        "name": "Widget",
        "offers": {
            "@type": "Person",
            "name": "Wrong Type"
        }
      }</script>''';

      final graph = extractAll(html);
      final result = validate(graph);
      expect(result.errors.any((d) => d.code == DiagnosticCode.invalidValueType), isTrue);
    });

    test('text where url expected warns', () {
      const html = '''<script type="application/ld+json">{
        "@context": "https://schema.org",
        "@type": "Product",
        "name": "Widget",
        "image": "not a URL"
      }</script>''';

      final graph = extractAll(html);
      final result = validate(graph);
      expect(result.warnings.any((d) => d.code == DiagnosticCode.expectedUrlGotText), isTrue);
    });

    test('diagnostic paths are descriptive', () {
      const html = '''<script type="application/ld+json">{
        "@context": "https://schema.org",
        "@type": "Product",
        "name": "Widget",
        "offers": {
            "@type": "Offer",
            "pricee": "29.99"
        }
      }</script>''';

      final graph = extractAll(html);
      final result = validate(graph);
      final unknown = result.errors.firstWhere((d) => d.code == DiagnosticCode.unknownProperty);
      expect(unknown.path, contains('Offer'));
      expect(unknown.path, contains('pricee'));
    });

    test('microdata validation', () {
      const html = '''<html><body>
      <div itemscope itemtype="https://schema.org/Product">
          <span itemprop="name">Widget</span>
          <span itemprop="unknownProp123">Bad</span>
      </div>
      </body></html>''';

      final graph = extractAll(html);
      final result = validate(graph);
      expect(result.errors.any((d) => d.code == DiagnosticCode.unknownProperty), isTrue);
    });

    test('rdfa validation', () {
      const html = '''<html><body>
      <div vocab="https://schema.org/" typeof="Produc">
          <span property="name">Widget</span>
      </div>
      </body></html>''';

      final graph = extractAll(html);
      final result = validate(graph);
      expect(result.errors.any((d) => d.code == DiagnosticCode.unknownType), isTrue);
    });

    test('empty graph no diagnostics', () {
      const html = '<html></html>';
      final graph = extractAll(html);
      final result = validate(graph);
      expect(result.isEmpty, isTrue);
    });

    test('validation result methods', () {
      const html = '''<script type="application/ld+json">{
        "@context": "https://schema.org",
        "@type": "Produc",
        "namee": "Test"
      }</script>''';

      final graph = extractAll(html);
      final result = validate(graph);
      expect(result.hasErrors, isTrue);
      expect(result.len, greaterThan(0));
      expect(result.isEmpty, isFalse);
      expect(result.errors.length, greaterThan(0));
    });

    test('valid product with offer no value errors', () {
      const html = '''<script type="application/ld+json">{
        "@context": "https://schema.org",
        "@type": "Product",
        "name": "Widget",
        "offers": {
            "@type": "Offer",
            "price": "29.99",
            "priceCurrency": "EUR",
            "availability": "https://schema.org/InStock"
        }
      }</script>''';

      final graph = extractAll(html);
      final result = validate(graph);
      expect(result.errors, isEmpty);
    });

    test('boolean string warns', () {
      const html = '''<script type="application/ld+json">{
        "@context": "https://schema.org",
        "@type": "Product",
        "name": "Widget",
        "isFamilyFriendly": "true"
      }</script>''';

      final graph = extractAll(html);
      final result = validate(graph);
      expect(result.warnings.any((d) => d.code == DiagnosticCode.invalidBoolean), isTrue);
    });

    test('boolean native no warning', () {
      const html = '''<script type="application/ld+json">{
        "@context": "https://schema.org",
        "@type": "Product",
        "name": "Widget",
        "isFamilyFriendly": true
      }</script>''';

      final graph = extractAll(html);
      final result = validate(graph);
      expect(result.diagnostics.any((d) => d.code == DiagnosticCode.invalidBoolean), isFalse);
    });
  });
}
