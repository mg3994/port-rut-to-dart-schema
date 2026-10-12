import '../models/diagnostics.dart';
import '../parser/html_extractor.dart';
import 'baseline_profile.dart';
import 'engine.dart';
import 'google_article_profile.dart';
import 'google_breadcrumb_profile.dart';
import 'google_event_profile.dart';
import 'google_faqpage_profile.dart';
import 'google_local_business_profile.dart';
import 'google_product_profile.dart';
import 'google_recipe_profile.dart';
import 'profile_interface.dart';

class ProfileRegistry {
  final List<Profile> _profiles = [];

  ProfileRegistry();

  factory ProfileRegistry.withGoogle() {
    final registry = ProfileRegistry();
    registry.registerAllGoogle();
    return registry;
  }

  factory ProfileRegistry.withBaseline() {
    final registry = ProfileRegistry();
    registry.register(BaselineProfile());
    return registry;
  }

  void register(Profile profile) {
    _profiles.add(profile);
  }

  void registerAllGoogle() {
    register(GoogleProductProfile());
    register(GoogleArticleProfile());
    register(GoogleFaqPageProfile());
    register(GoogleBreadcrumbProfile());
    register(GoogleLocalBusinessProfile());
    register(GoogleEventProfile());
    register(GoogleRecipeProfile());
  }

  List<String> get profileNames =>
      _profiles.map((p) => p.name).toSet().toList();

  ProfileResult evaluate(
    String profileName,
    StructuredDataGraph graph,
    List<ValidationDiagnostic> vocabDiagnostics,
  ) {
    final matching = _profiles.where((p) => p.name == profileName).toList();

    if (matching.isEmpty) {
      throw ProfileException("unknown profile: '$profileName'");
    }

    final allTypeResults = <TypeEligibility>[];
    final allDiagnostics = <ValidationDiagnostic>[];

    for (final profile in matching) {
      final result = evaluateGraph(profile, graph, vocabDiagnostics);
      allTypeResults.addAll(result.typeResults);
      allDiagnostics.addAll(result.diagnostics);
    }

    final eligibility = aggregateEligibility(allTypeResults, allDiagnostics);

    return ProfileResult(
      eligibility: eligibility,
      typeResults: allTypeResults,
      diagnostics: allDiagnostics,
    );
  }
}
