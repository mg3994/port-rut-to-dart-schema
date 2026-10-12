import '../models/diagnostics.dart';
import '../models/schema_node.dart';
import 'google_common.dart';
import 'profile_interface.dart';

class GoogleEventProfile implements Profile {
  @override
  String get name => 'google';

  @override
  String get version => '2026-04-01';

  @override
  String get sourceUrl =>
      'https://developers.google.com/search/docs/appearance/structured-data/event';

  @override
  List<String> get supportedTypes => const ['Event'];

  @override
  NodeProfileResult evaluateNode(
    SchemaNode node,
    List<ValidationDiagnostic> vocabDiagnostics,
  ) {
    final typeName = node.types.isNotEmpty ? node.types.first : 'Event';
    final path = typeName;
    final diagnostics = <ValidationDiagnostic>[];
    final requiredMissing = <String>[];
    final recommendedMissing = <String>[];

    for (final prop in const ['name', 'startDate', 'location']) {
      final d = requireProperty(node, prop, path);
      if (d != null) {
        requiredMissing.add(prop);
        diagnostics.add(d);
      }
    }

    for (final prop in const [
      'image',
      'description',
      'endDate',
      'offers',
      'performer',
      'organizer',
      'eventStatus',
      'eventAttendanceMode',
    ]) {
      final d = recommendProperty(node, prop, path);
      if (d != null) {
        recommendedMissing.add(prop);
        diagnostics.add(d);
      }
    }

    final placeDiags = validateNested(
      node,
      'location',
      'Place',
      const ['name', 'address'],
      const [],
      path,
    );
    diagnostics.addAll(placeDiags);

    final virtualDiags = validateNested(
      node,
      'location',
      'VirtualLocation',
      const ['url'],
      const [],
      path,
    );
    diagnostics.addAll(virtualDiags);

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
