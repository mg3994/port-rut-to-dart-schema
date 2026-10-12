import 'package:schemaorg_validate/schemaorg_validate.dart';
import 'package:test/test.dart';

ProfileResult evalHtml(String html, String profile) {
  final graph = extractAll(html);
  final vocab = validate(graph);
  final reg = ProfileRegistry.withGoogle();
  return reg.evaluate(profile, graph, vocab.diagnostics);
}

String jsonld(String json) {
  return '<html><head><script type="application/ld+json">$json</script></head></html>';
}

void main() {
  group('Profile System', () {
    test('registry google has profiles', () {
      final reg = ProfileRegistry.withGoogle();
      expect(reg.profileNames, contains('google'));
    });

    test('registry baseline has profiles', () {
      final reg = ProfileRegistry.withBaseline();
      expect(reg.profileNames, contains('baseline'));
    });

    test('unknown profile errors', () {
      final reg = ProfileRegistry();
      final graph = extractAll('<html></html>');
      expect(() => reg.evaluate('nope', graph, []), throwsA(isA<ProfileException>()));
    });

    test('empty graph not eligible', () {
      final r = evalHtml('<html></html>', 'google');
      expect(r.eligibility, Eligibility.notEligible);
    });

    test('product valid eligible', () {
      final html = jsonld('''{
        "@context":"https://schema.org","@type":"Product",
        "name":"Widget","image":"https://x.com/w.jpg","description":"A widget",
        "brand":{"@type":"Brand","name":"Acme"},"sku":"W123","gtin":"012345678",
        "offers":{"@type":"Offer","price":"10","priceCurrency":"USD",
        "availability":"https://schema.org/InStock"},
        "aggregateRating":{"@type":"AggregateRating","ratingValue":"4.5","ratingCount":"10"},
        "review":{"@type":"Review","author":{"@type":"Person","name":"Bob"}}
      }''');
      final r = evalHtml(html, 'google');
      expect(r.eligibility, Eligibility.warningsOnly);
      expect(r.typeResults.any((t) => t.schemaType == 'Product' && t.eligible), isTrue);
    });

    test('product missing name not eligible', () {
      final html = jsonld('{"@context":"https://schema.org","@type":"Product","sku":"X"}');
      final r = evalHtml(html, 'google');
      expect(r.eligibility, Eligibility.notEligible);
      expect(r.typeResults.first.requiredMissing, contains('name'));
    });

    test('product name only warnings', () {
      final html = jsonld('{"@context":"https://schema.org","@type":"Product","name":"W"}');
      final r = evalHtml(html, 'google');
      expect(r.typeResults.first.eligible, isTrue);
      expect(r.typeResults.first.recommendedMissing, isNotEmpty);
    });

    test('product nested offer missing price', () {
      final html = jsonld('''{
        "@context":"https://schema.org","@type":"Product","name":"W",
        "offers":{"@type":"Offer","priceCurrency":"USD"}
      }''');
      final r = evalHtml(html, 'google');
      expect(r.eligibility, Eligibility.notEligible);
      expect(r.diagnostics.any((d) => d.path.contains('offers') && d.path.contains('price')), isTrue);
    });

    test('product aggregate rating needs count', () {
      final html = jsonld('''{
        "@context":"https://schema.org","@type":"Product","name":"W",
        "aggregateRating":{"@type":"AggregateRating","ratingValue":"4"}
      }''');
      final r = evalHtml(html, 'google');
      expect(r.diagnostics.any((d) => d.path.contains('aggregateRating') && d.message.contains('ratingCount')), isTrue);
    });

    test('article valid eligible', () {
      final html = jsonld('''{
        "@context":"https://schema.org","@type":"Article",
        "headline":"Test","image":"https://x.com/a.jpg","datePublished":"2024-01-01",
        "author":{"@type":"Person","name":"Alice"}
      }''');
      final r = evalHtml(html, 'google');
      expect(r.typeResults.first.eligible, isTrue);
    });

    test('article missing headline', () {
      final html = jsonld('''{
        "@context":"https://schema.org","@type":"Article",
        "image":"https://x.com/a.jpg","datePublished":"2024-01-01",
        "author":{"@type":"Person","name":"A"}
      }''');
      final r = evalHtml(html, 'google');
      expect(r.typeResults.first.eligible, isFalse);
      expect(r.typeResults.first.requiredMissing, contains('headline'));
    });

    test('newsarticle subtype matched', () {
      final html = jsonld('''{
        "@context":"https://schema.org","@type":"NewsArticle",
        "headline":"News","image":"https://x.com/a.jpg","datePublished":"2024-01-01",
        "author":{"@type":"Person","name":"A"}
      }''');
      final r = evalHtml(html, 'google');
      expect(r.typeResults.first.eligible, isTrue);
      expect(r.typeResults.first.schemaType, 'NewsArticle');
    });

    test('blogposting subtype matched', () {
      final html = jsonld('''{
        "@context":"https://schema.org","@type":"BlogPosting",
        "headline":"Blog","image":"https://x.com/b.jpg","datePublished":"2024-01-01",
        "author":{"@type":"Person","name":"A"}
      }''');
      final r = evalHtml(html, 'google');
      expect(r.typeResults.first.eligible, isTrue);
    });

    test('article author missing name', () {
      final html = jsonld('''{
        "@context":"https://schema.org","@type":"Article",
        "headline":"T","image":"https://x.com/a.jpg","datePublished":"2024-01-01",
        "author":{"@type":"Person","url":"https://x.com"}
      }''');
      final r = evalHtml(html, 'google');
      expect(r.diagnostics.any((d) => d.path.contains('author') && d.path.contains('name')), isTrue);
    });

    test('faqpage valid restricted', () {
      final html = jsonld('''{
        "@context":"https://schema.org","@type":"FAQPage",
        "mainEntity":[{"@type":"Question","name":"Q1",
        "acceptedAnswer":{"@type":"Answer","text":"A1"}}]
      }''');
      final r = evalHtml(html, 'google');
      expect(r.eligibility, Eligibility.restricted);
      expect(r.typeResults.first.eligible, isTrue);
    });

    test('faqpage missing main entity', () {
      final html = jsonld('{"@context":"https://schema.org","@type":"FAQPage"}');
      final r = evalHtml(html, 'google');
      expect(r.typeResults.first.requiredMissing, contains('mainEntity'));
    });

    test('faqpage question missing answer', () {
      final html = jsonld('''{
        "@context":"https://schema.org","@type":"FAQPage",
        "mainEntity":[{"@type":"Question","name":"Q1"}]
      }''');
      final r = evalHtml(html, 'google');
      expect(r.diagnostics.any((d) => d.path.contains('acceptedAnswer')), isTrue);
    });

    test('faqpage answer missing text', () {
      final html = jsonld('''{
        "@context":"https://schema.org","@type":"FAQPage",
        "mainEntity":[{"@type":"Question","name":"Q1",
        "acceptedAnswer":{"@type":"Answer"}}]
      }''');
      final r = evalHtml(html, 'google');
      expect(r.diagnostics.any((d) => d.path.contains('text')), isTrue);
    });

    test('breadcrumb valid eligible', () {
      final html = jsonld('''{
        "@context":"https://schema.org","@type":"BreadcrumbList",
        "itemListElement":[
            {"@type":"ListItem","position":1,"name":"Home","item":"https://x.com"},
            {"@type":"ListItem","position":2,"name":"Category","item":"https://x.com/cat"},
            {"@type":"ListItem","position":3,"name":"Page"}
        ]
      }''');
      final r = evalHtml(html, 'google');
      expect(r.typeResults.first.eligible, isTrue);
    });

    test('breadcrumb missing items', () {
      final html = jsonld('{"@context":"https://schema.org","@type":"BreadcrumbList"}');
      final r = evalHtml(html, 'google');
      expect(r.typeResults.first.eligible, isFalse);
    });

    test('breadcrumb wrong position', () {
      final html = jsonld('''{
        "@context":"https://schema.org","@type":"BreadcrumbList",
        "itemListElement":[
            {"@type":"ListItem","position":5,"name":"Home","item":"https://x.com"}
        ]
      }''');
      final r = evalHtml(html, 'google');
      expect(r.diagnostics.any((d) => d.path.contains('position')), isTrue);
    });

    test('breadcrumb last item no url ok', () {
      final html = jsonld('''{
        "@context":"https://schema.org","@type":"BreadcrumbList",
        "itemListElement":[
            {"@type":"ListItem","position":1,"name":"Home","item":"https://x.com"},
            {"@type":"ListItem","position":2,"name":"Current"}
        ]
      }''');
      final r = evalHtml(html, 'google');
      final hasItemError = r.diagnostics.any((d) => d.path.contains('[1].item') && d.severity == Severity.error);
      expect(hasItemError, isFalse);
    });

    test('local business valid', () {
      final html = jsonld('''{
        "@context":"https://schema.org","@type":"LocalBusiness",
        "name":"Acme Shop","address":{"@type":"PostalAddress",
        "streetAddress":"123 Main St","addressLocality":"Springfield",
        "postalCode":"12345","addressCountry":"US"}
      }''');
      final r = evalHtml(html, 'google');
      expect(r.typeResults.first.eligible, isTrue);
    });

    test('local business missing address', () {
      final html = jsonld('''{
        "@context":"https://schema.org","@type":"LocalBusiness",
        "name":"Acme Shop"}''');
      final r = evalHtml(html, 'google');
      expect(r.typeResults.first.eligible, isFalse);
      expect(r.typeResults.first.requiredMissing, contains('address'));
    });

    test('restaurant subtype via inheritance', () {
      final html = jsonld('''{
        "@context":"https://schema.org","@type":"Restaurant",
        "name":"Pizza Place","address":{"@type":"PostalAddress",
        "streetAddress":"1 St","addressLocality":"Town",
        "postalCode":"000","addressCountry":"US"}
      }''');
      final r = evalHtml(html, 'google');
      expect(r.typeResults, isNotEmpty);
      expect(r.typeResults.first.eligible, isTrue);
    });

    test('local business address missing fields', () {
      final html = jsonld('''{
        "@context":"https://schema.org","@type":"LocalBusiness",
        "name":"Shop","address":{"@type":"PostalAddress","streetAddress":"1 St"}}''');
      final r = evalHtml(html, 'google');
      expect(r.diagnostics.any((d) => d.path.contains('addressLocality')), isTrue);
    });

    test('event valid', () {
      final html = jsonld('''{
        "@context":"https://schema.org","@type":"Event",
        "name":"Concert","startDate":"2024-06-01T20:00",
        "location":{"@type":"Place","name":"Venue","address":"123 St"}}''');
      final r = evalHtml(html, 'google');
      expect(r.typeResults.first.eligible, isTrue);
    });

    test('event missing start date', () {
      final html = jsonld('''{
        "@context":"https://schema.org","@type":"Event",
        "name":"Concert","location":{"@type":"Place","name":"V","address":"1"}}''');
      final r = evalHtml(html, 'google');
      expect(r.typeResults.first.eligible, isFalse);
      expect(r.typeResults.first.requiredMissing, contains('startDate'));
    });

    test('event missing location', () {
      final html = jsonld('''{
        "@context":"https://schema.org","@type":"Event",
        "name":"Concert","startDate":"2024-06-01T20:00"}''');
      final r = evalHtml(html, 'google');
      expect(r.typeResults.first.eligible, isFalse);
    });

    test('event recommended fields warned', () {
      final html = jsonld('''{
        "@context":"https://schema.org","@type":"Event",
        "name":"E","startDate":"2024-06-01","location":{"@type":"Place",
        "name":"V","address":"1"}}''');
      final r = evalHtml(html, 'google');
      expect(r.typeResults.first.recommendedMissing, isNotEmpty);
    });

    test('recipe valid', () {
      final html = jsonld('''{
        "@context":"https://schema.org","@type":"Recipe",
        "name":"Cake","image":"https://x.com/cake.jpg"}''');
      final r = evalHtml(html, 'google');
      expect(r.typeResults.first.eligible, isTrue);
    });
  });
}
