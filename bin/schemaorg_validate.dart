import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:schemaorg_validate/schemaorg_validate.dart';

void main(List<String> args) {
  final parser = ArgParser()
    ..addOption('file', abbr: 'f', help: 'Path to HTML or JSON-LD file')
    ..addFlag('stdin', help: 'Read HTML/JSON-LD from standard input', negatable: false)
    ..addOption('profile',
        abbr: 'p',
        defaultsTo: 'google',
        allowed: ['google', 'baseline', 'none'],
        help: 'Profile to check against')
    ..addOption('format',
        defaultsTo: 'text',
        allowed: ['text', 'json', 'sarif'],
        help: 'Output format')
    ..addFlag('no-color', help: 'Disable colored text output', negatable: false)
    ..addFlag('help', abbr: 'h', help: 'Show usage information', negatable: false);

  ArgResults results;
  try {
    results = parser.parse(args);
  } catch (e) {
    stderr.writeln('Error parsing arguments: $e\n');
    _printUsage(parser);
    exit(1);
  }

  if (results['help'] as bool) {
    _printUsage(parser);
    exit(0);
  }

  String content = '';
  String sourceName = '';

  final filePath = results['file'] as String?;
  final isStdin = results['stdin'] as bool;

  if (filePath != null) {
    final file = File(filePath);
    if (!file.existsSync()) {
      stderr.writeln("File not found: '$filePath'");
      exit(1);
    }
    content = file.readAsStringSync();
    sourceName = filePath;
  } else if (isStdin) {
    content = stdin.readLineSync() ?? '';
    sourceName = '<stdin>';
  } else {
    stderr.writeln('No input provided. Use --file or --stdin.\n');
    _printUsage(parser);
    exit(1);
  }

  final graph = extractAll(content);
  final vocabResult = validate(graph);

  final profileChoice = results['profile'] as String;
  ProfileResult? profileResult;

  if (profileChoice == 'google') {
    final registry = ProfileRegistry.withGoogle();
    profileResult = registry.evaluate('google', graph, vocabResult.diagnostics);
  } else if (profileChoice == 'baseline') {
    final registry = ProfileRegistry.withBaseline();
    profileResult = registry.evaluate('baseline', graph, vocabResult.diagnostics);
  }

  final format = results['format'] as String;
  final useColor = !(results['no-color'] as bool);

  if (format == 'text') {
    _printTextOutput(vocabResult, profileResult, sourceName, graph, useColor, profileChoice);
  } else if (format == 'json') {
    _printJsonOutput(vocabResult, profileResult, sourceName, graph);
  } else if (format == 'sarif') {
    _printSarifOutput(vocabResult, profileResult, sourceName);
  }

  final hasVocabErrors = vocabResult.hasErrors;
  final hasProfileErrors =
      profileResult != null && profileResult.eligibility == Eligibility.notEligible;

  if (hasVocabErrors || hasProfileErrors) {
    exit(1);
  }
}

void _printUsage(ArgParser parser) {
  print('Usage: schemaorg_validate [options]\n');
  print(parser.usage);
}

void _printTextOutput(
  ValidationResult vocabResult,
  ProfileResult? profileResult,
  String sourceName,
  StructuredDataGraph graph,
  bool useColor,
  String profileChoice,
) {
  final red = useColor ? '\x1b[31m' : '';
  final yellow = useColor ? '\x1b[33m' : '';
  final blue = useColor ? '\x1b[34m' : '';
  final green = useColor ? '\x1b[32m' : '';
  final bold = useColor ? '\x1b[1m' : '';
  final dim = useColor ? '\x1b[2m' : '';
  final reset = useColor ? '\x1b[0m' : '';

  print('\n$dim-- schemaorg-validate ----------------------------------------$reset');
  print('  ${bold}Source:$reset  $sourceName');
  if (profileChoice != 'none') {
    print('  ${bold}Profile:$reset $profileChoice');
  }
  print('  ${bold}Schema.org:$reset v${schemaVersion()}');

  if (vocabResult.isEmpty) {
    print('\n  $green\u2713 No vocabulary issues found$reset');
  } else {
    print('\n$dim-- Vocabulary -----------------------------------------------$reset');
    for (final diag in vocabResult.diagnostics) {
      _printDiagnostic(diag, red, yellow, blue, reset);
    }
  }

  if (profileResult != null) {
    print('\n$dim-- Profile Results ------------------------------------------$reset');
    for (final tr in profileResult.typeResults) {
      final status = tr.eligible ? '${green}ELIGIBLE$reset' : '${red}NOT ELIGIBLE$reset';
      print('  $bold${tr.schemaType}$reset: $status');

      if (tr.requiredMissing.isNotEmpty) {
        print('    ${red}Required missing:$reset ${tr.requiredMissing.join(", ")}');
      }
      if (tr.recommendedMissing.isNotEmpty) {
        print('    ${yellow}Recommended missing:$reset ${tr.recommendedMissing.join(", ")}');
      }
    }

    for (final diag in profileResult.diagnostics) {
      _printDiagnostic(diag, red, yellow, blue, reset);
    }

    final eligStr = switch (profileResult.eligibility) {
      Eligibility.eligible => '${green}Eligible$reset',
      Eligibility.warningsOnly => '${yellow}Eligible (with warnings)$reset',
      Eligibility.notEligible => '${red}Not Eligible$reset',
      Eligibility.restricted => '${blue}Restricted$reset',
    };
    print('\n  ${bold}Eligibility:$reset $eligStr');
  }

  final errorCount = vocabResult.errors.length +
      (profileResult?.diagnostics.where((d) => d.severity == Severity.error).length ?? 0);
  final warningCount = vocabResult.warnings.length +
      (profileResult?.diagnostics.where((d) => d.severity == Severity.warning).length ?? 0);

  print('\n  $errorCount error(s), $warningCount warning(s)\n');
}

void _printDiagnostic(
  ValidationDiagnostic diag,
  String red,
  String yellow,
  String blue,
  String reset,
) {
  final (icon, color, label) = switch (diag.severity) {
    Severity.error => ('\u2717', red, 'ERROR'),
    Severity.warning => ('\u26a0', yellow, 'WARN '),
    Severity.info => ('\u2139', blue, 'INFO '),
  };

  print('  $color$icon $label$reset  ${diag.path} -- ${diag.message}');
}

void _printJsonOutput(
  ValidationResult vocabResult,
  ProfileResult? profileResult,
  String sourceName,
  StructuredDataGraph graph,
) {
  final formats = graph.nodes.map((n) => n.sourceFormat.toString()).toSet().toList();

  final Map<String, dynamic> jsonMap = {
    'source': sourceName,
    'schema_version': schemaVersion(),
    'extraction': {
      'node_count': graph.nodes.length,
      'formats': formats,
      'warning_count': graph.warnings.length,
    },
    'vocabulary': {
      'error_count': vocabResult.errors.length,
      'warning_count': vocabResult.warnings.length,
      'diagnostics': vocabResult.diagnostics.map((d) => d.toString()).toList(),
    },
  };

  if (profileResult != null) {
    jsonMap['profile'] = {
      'eligibility': profileResult.eligibility.toString(),
      'type_results': profileResult.typeResults
          .map((tr) => {
                'schema_type': tr.schemaType,
                'eligible': tr.eligible,
                'required_missing': tr.requiredMissing,
                'recommended_missing': tr.recommendedMissing,
              })
          .toList(),
      'diagnostics': profileResult.diagnostics.map((d) => d.toString()).toList(),
    };
  }

  print(const JsonEncoder.withIndent('  ').convert(jsonMap));
}

void _printSarifOutput(
  ValidationResult vocabResult,
  ProfileResult? profileResult,
  String sourceName,
) {
  final sarif = buildSarif(
    vocabResult.diagnostics,
    profileResult?.diagnostics,
    sourceName,
  );
  print(const JsonEncoder.withIndent('  ').convert(sarif));
}
