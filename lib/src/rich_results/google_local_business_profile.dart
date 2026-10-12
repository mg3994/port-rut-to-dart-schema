import '../models/diagnostics.dart';
import '../models/schema_node.dart';
import 'google_common.dart';
import 'profile_interface.dart';

class GoogleLocalBusinessProfile implements Profile {
  @override
  String get name => 'google';

  @override
  String get version => '2026-04-01';

  @override
  String get sourceUrl =>
      'https://developers.google.com/search/docs/appearance/structured-data/local-business';

  @override
  List<String> get supportedTypes => const ['LocalBusiness'];

  @override
  NodeProfileResult evaluateNode(
    SchemaNode node,
    List<ValidationDiagnostic> vocabDiagnostics,
  ) {
    final typeName = node.types.isNotEmpty ? node.types.first : 'LocalBusiness';
    final path = typeName;
    final diagnostics = <ValidationDiagnostic>[];
    final requiredMissing = <String>[];
    final recommendedMissing = <String>[];

    final dName = requireProperty(node, 'name', path);
    if (dName != null) {
      requiredMissing.add('name');
      diagnostics.add(dName);
    }

    final dAddr = requireProperty(node, 'address', path);
    if (dAddr != null) {
      requiredMissing.add('address');
      diagnostics.add(dAddr);
    }

    for (final prop in const [
      'image',
      'telephone',
      'url',
      'openingHoursSpecification',
      'geo',
      'priceRange',
    ]) {
      final d = recommendProperty(node, prop, path);
      if (d != null) {
        recommendedMissing.add(prop);
        diagnostics.add(d);
      }
    }

    final addressDiags = validateNested(
      node,
      'address',
      'PostalAddress',
      const [
        'streetAddress',
        'addressLocality',
        'postalCode',
        'addressCountry',
      ],
      const ['addressRegion'],
      path,
    );
    diagnostics.addAll(addressDiags);

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
