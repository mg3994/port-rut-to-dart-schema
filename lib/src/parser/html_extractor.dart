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

  /// Converts this [StructuredDataGraph] into a list of JSON-compatible Maps.
  List<Map<String, dynamic>> toJson() =>
      nodes.map((n) => n.toJson()).toList();

  /// Deserializes a list of JSON maps into a [StructuredDataGraph].
  factory StructuredDataGraph.fromJson(
    List<dynamic> jsonList, {
    List<ExtractionWarning> warnings = const [],
  }) {
    final nodes = <SchemaNode>[];
    for (final item in jsonList) {
      if (item is Map<String, dynamic>) {
        nodes.add(SchemaNode.fromJson(item));
      } else if (item is Map) {
        nodes.add(SchemaNode.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    return StructuredDataGraph(nodes: nodes, warnings: warnings);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! StructuredDataGraph) return false;
    if (nodes.length != other.nodes.length) return false;
    for (var i = 0; i < nodes.length; i++) {
      if (nodes[i] != other.nodes[i]) return false;
    }
    if (warnings.length != other.warnings.length) return false;
    for (var i = 0; i < warnings.length; i++) {
      if (warnings[i] != other.warnings[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(nodes),
        Object.hashAll(warnings),
      );

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
