import 'dart:convert';
import 'package:schemaorg_validate/schemaorg_validate.dart';

void main() {
  const html = '''
<html>
  <head>
    <script type="application/ld+json">
    {
      "@context": "https://schema.org",
      "@type": "Product",
      "name": "Super Widget",
      "image": "https://example.com/widget.jpg",
      "description": "High performance widget",
      "offers": {
        "@type": "Offer",
        "price": "29.99",
        "priceCurrency": "USD",
        "availability": "https://schema.org/InStock"
      }
    }
    </script>
  </head>
</html>
''';

  print('=== 1. Extracting Structured Data ===');
  final graph = extractAll(html);
  print('Extracted ${graph.nodes.length} node(s)');
  for (final node in graph.nodes) {
    print('Node types: ${node.types}');
    print('Properties: ${node.properties.keys.toList()}');
  }

  print('\n=== 2. Validating Against Schema.org Vocabulary ===');
  final vocabResult = validate(graph);
  if (vocabResult.hasErrors) {
    print('Vocabulary Errors:');
    for (final err in vocabResult.errors) {
      print('  - [${err.code}] ${err.path}: ${err.message}');
    }
  } else {
    print('No vocabulary errors found!');
  }

  print('\n=== 3. Checking Google Rich Results Profiles ===');
  final registry = ProfileRegistry.withGoogle();
  final profileResult = registry.evaluate('google', graph, vocabResult.diagnostics);

  print('Overall Eligibility: ${profileResult.eligibility}');
  for (final typeRes in profileResult.typeResults) {
    print('Type: ${typeRes.schemaType}');
    print('  Eligible: ${typeRes.eligible}');
    print('  Required missing: ${typeRes.requiredMissing}');
    print('  Recommended missing: ${typeRes.recommendedMissing}');
  }

  print('\n=== 4. Generating SARIF Output ===');
  final sarif = buildSarif(
    vocabResult.diagnostics,
    profileResult.diagnostics,
    'example.html',
  );
  print(const JsonEncoder.withIndent('  ').convert(sarif));
}
