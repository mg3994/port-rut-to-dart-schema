import '../models/diagnostics.dart';
import '../models/schema_node.dart';
import 'google_common.dart';
import 'profile_interface.dart';

class GoogleArticleProfile implements Profile {
  @override
  String get name => 'google';

  @override
  String get version => '2026-04-01';

  @override
  String get sourceUrl =>
      'https://developers.google.com/search/docs/appearance/structured-data/article';

  @override
  List<String> get supportedTypes => const [
        'Article',
        'NewsArticle',
        'BlogPosting',
        'TechArticle',
        'ScholarlyArticle',
      ];

  @override
  NodeProfileResult evaluateNode(
    SchemaNode node,
    List<ValidationDiagnostic> vocabDiagnostics,
  ) {
    final typeName = node.types.isNotEmpty ? node.types.first : 'Article';
    final path = typeName;
    final diagnostics = <ValidationDiagnostic>[];
    final requiredMissing = <String>[];
    final recommendedMissing = <String>[];

    for (final prop in const ['headline', 'image', 'datePublished', 'author']) {
      final d = requireProperty(node, prop, path);
      if (d != null) {
        requiredMissing.add(prop);
        diagnostics.add(d);
      }
    }

    for (final prop in const ['dateModified', 'publisher', 'mainEntityOfPage']) {
      final d = recommendProperty(node, prop, path);
      if (d != null) {
        recommendedMissing.add(prop);
        diagnostics.add(d);
      }
    }

    final authorDiags = validateNested(
      node,
      'author',
      'Person',
      const ['name'],
      const ['url'],
      path,
    );
    diagnostics.addAll(authorDiags);

    final publisherDiags = validateNested(
      node,
      'publisher',
      'Organization',
      const ['name'],
      const ['logo'],
      path,
    );
    diagnostics.addAll(publisherDiags);

    final eligible = requiredMissing.isEmpty;

    return NodeProfileResult(
      typeEligibility: TypeEligibility(
        schemaType: typeName,
        eligible: eligible,
        requiredMissing: requiredMissing,
        recommendedMissing: recommendedMissing,
        fieldDiagnostics: diagnostics,
      ),
    );
  }
}
