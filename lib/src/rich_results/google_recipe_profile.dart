import '../models/diagnostics.dart';
import '../models/schema_node.dart';
import 'google_common.dart';
import 'profile_interface.dart';

class GoogleRecipeProfile implements Profile {
  @override
  String get name => 'google';

  @override
  String get version => '2026-04-01';

  @override
  String get sourceUrl =>
      'https://developers.google.com/search/docs/appearance/structured-data/recipe';

  @override
  List<String> get supportedTypes => const ['Recipe'];

  @override
  NodeProfileResult evaluateNode(
    SchemaNode node,
    List<ValidationDiagnostic> vocabDiagnostics,
  ) {
    const path = 'Recipe';
    final diagnostics = <ValidationDiagnostic>[];
    final requiredMissing = <String>[];
    final recommendedMissing = <String>[];

    for (final prop in const ['name', 'image']) {
      final d = requireProperty(node, prop, path);
      if (d != null) {
        requiredMissing.add(prop);
        diagnostics.add(d);
      }
    }

    for (final prop in const [
      'author',
      'datePublished',
      'description',
      'recipeCuisine',
      'prepTime',
      'cookTime',
      'totalTime',
      'recipeYield',
      'recipeCategory',
      'recipeIngredient',
      'recipeInstructions',
      'nutrition',
      'video',
    ]) {
      final d = recommendProperty(node, prop, path);
      if (d != null) {
        recommendedMissing.add(prop);
        diagnostics.add(d);
      }
    }

    final stepDiags = validateNested(
      node,
      'recipeInstructions',
      'HowToStep',
      const ['text'],
      const [],
      path,
    );
    diagnostics.addAll(stepDiags);

    final eligible = requiredMissing.isEmpty;

    return NodeProfileResult(
      typeEligibility: TypeEligibility(
        schemaType: 'Recipe',
        eligible: eligible,
        requiredMissing: requiredMissing,
        recommendedMissing: recommendedMissing,
        fieldDiagnostics: diagnostics,
      ),
    );
  }
}
