import '../models/diagnostics.dart';
import '../models/schema_node.dart';
import 'google_common.dart';
import 'profile_interface.dart';

class GoogleProductProfile implements Profile {
  @override
  String get name => 'google';

  @override
  String get version => '2026-04-01';

  @override
  String get sourceUrl =>
      'https://developers.google.com/search/docs/appearance/structured-data/product';

  @override
  List<String> get supportedTypes => const ['Product'];

  @override
  NodeProfileResult evaluateNode(
    SchemaNode node,
    List<ValidationDiagnostic> vocabDiagnostics,
  ) {
    const path = 'Product';
    final diagnostics = <ValidationDiagnostic>[];
    final requiredMissing = <String>[];
    final recommendedMissing = <String>[];

    final dName = requireProperty(node, 'name', path);
    if (dName != null) {
      requiredMissing.add('name');
      diagnostics.add(dName);
    }

    for (final prop in const ['image', 'description', 'brand', 'sku']) {
      final d = recommendProperty(node, prop, path);
      if (d != null) {
        recommendedMissing.add(prop);
        diagnostics.add(d);
      }
    }

    final dGtin = requireOneOf(
      node,
      const ['gtin', 'gtin8', 'gtin13', 'gtin14', 'isbn', 'mpn'],
      path,
      Severity.warning,
    );
    if (dGtin != null) {
      recommendedMissing.add('gtin/isbn/mpn');
      diagnostics.add(dGtin);
    }

    final dOffers = requireOneOf(
      node,
      const ['offers', 'aggregateOffer'],
      path,
      Severity.warning,
    );
    if (dOffers != null) {
      recommendedMissing.add('offers');
      diagnostics.add(dOffers);
    }

    final dRating = requireOneOf(
      node,
      const ['aggregateRating', 'review'],
      path,
      Severity.warning,
    );
    if (dRating != null) {
      recommendedMissing.add('aggregateRating/review');
      diagnostics.add(dRating);
    }

    final offerDiags = validateNested(
      node,
      'offers',
      'Offer',
      const ['price', 'priceCurrency', 'availability'],
      const ['url', 'priceValidUntil', 'itemCondition'],
      path,
    );
    diagnostics.addAll(offerDiags);

    final aggOfferDiags = validateNested(
      node,
      'aggregateOffer',
      'AggregateOffer',
      const ['lowPrice', 'priceCurrency'],
      const ['highPrice'],
      path,
    );
    diagnostics.addAll(aggOfferDiags);

    for (final ratingNode in getNestedNodes(node, 'aggregateRating')) {
      const ratingPath = '$path.aggregateRating';
      final dVal = requireProperty(ratingNode, 'ratingValue', ratingPath);
      if (dVal != null) diagnostics.add(dVal);

      final dCnt = requireOneOf(
        ratingNode,
        const ['ratingCount', 'reviewCount'],
        ratingPath,
        Severity.error,
      );
      if (dCnt != null) diagnostics.add(dCnt);
    }

    final reviewDiags = validateNested(
      node,
      'review',
      'Review',
      const ['author'],
      const ['reviewRating'],
      path,
    );
    diagnostics.addAll(reviewDiags);

    final eligible = requiredMissing.isEmpty &&
        !diagnostics.any((d) => d.code == DiagnosticCode.nestedRequiredFieldMissing);

    return NodeProfileResult(
      typeEligibility: TypeEligibility(
        schemaType: 'Product',
        eligible: eligible,
        requiredMissing: requiredMissing,
        recommendedMissing: recommendedMissing,
        fieldDiagnostics: diagnostics,
      ),
    );
  }
}
