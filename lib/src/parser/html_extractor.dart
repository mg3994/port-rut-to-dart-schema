import 'package:html/parser.dart' as html_parser;

import '../models/extraction_warning.dart';
import '../models/schema_node.dart';
import 'jsonld_parser.dart';
import 'microdata_parser.dart';
import 'rdfa_parser.dart';

class StructuredDataGraph {
  final List<SchemaNode> nodes;
  final List<ExtractionWarning> warnings;

  StructuredDataGraph({
    required this.nodes,
    required this.warnings,
  });

  @override
  String toString() =>
      'StructuredDataGraph(nodes: ${nodes.length}, warnings: ${warnings.length})';
}

/// Extracts all structured data (JSON-LD, Microdata, RDFa Lite) from an HTML string.
StructuredDataGraph extractAll(String html) {
  final doc = html_parser.parse(html);

  final nodes = <SchemaNode>[];
  final warnings = <ExtractionWarning>[];

  try {
    final jsonLdOutput = JsonLdExtractor().extractFromDocument(doc, html);
    nodes.addAll(jsonLdOutput.nodes);
    warnings.addAll(jsonLdOutput.warnings);
  } catch (e) {
    warnings.add(ExtractionWarning(
      message: 'extractor failed: $e',
      sourceLocation: null,
      code: WarningCode.extractorFailed,
    ));
  }

  try {
    final microdataOutput = MicrodataExtractor().extractFromDocument(doc);
    nodes.addAll(microdataOutput.nodes);
    warnings.addAll(microdataOutput.warnings);
  } catch (e) {
    warnings.add(ExtractionWarning(
      message: 'extractor failed: $e',
      sourceLocation: null,
      code: WarningCode.extractorFailed,
    ));
  }

  try {
    final rdfaOutput = RdfaLiteExtractor().extractFromDocument(doc);
    nodes.addAll(rdfaOutput.nodes);
    warnings.addAll(rdfaOutput.warnings);
  } catch (e) {
    warnings.add(ExtractionWarning(
      message: 'extractor failed: $e',
      sourceLocation: null,
      code: WarningCode.extractorFailed,
    ));
  }

  return StructuredDataGraph(nodes: nodes, warnings: warnings);
}
