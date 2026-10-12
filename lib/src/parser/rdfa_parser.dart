import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../models/extraction_warning.dart';
import '../models/schema_node.dart';
import '../models/schema_value.dart';
import '../models/source_format.dart';
import 'common.dart';
import 'jsonld_parser.dart' show ExtractionOutput;

const int maxDepth = 20;

class RdfaContext {
  final String? vocab;
  final Map<String, String> prefixes;

  const RdfaContext({
    this.vocab,
    this.prefixes = const {},
  });

  RdfaContext? updated(dom.Element el) {
    final hasVocab = el.attributes.containsKey('vocab');
    final hasPrefix = el.attributes.containsKey('prefix');

    if (!hasVocab && !hasPrefix) return null;

    var newVocab = vocab;
    final newPrefixes = Map<String, String>.from(prefixes);

    if (hasVocab) {
      final rawVocab = el.attributes['vocab']!;
      newVocab = rawVocab.isEmpty ? null : _ensureTrailingSlash(rawVocab);
    }

    if (hasPrefix) {
      _parsePrefixAttr(el.attributes['prefix']!, newPrefixes);
    }

    return RdfaContext(
      vocab: newVocab,
      prefixes: newPrefixes,
    );
  }

  String resolveTerm(String term) {
    final stripped = stripSchemaPrefix(term);
    if (stripped != term) {
      return stripped;
    }

    final colonPos = term.indexOf(':');
    if (colonPos != -1) {
      final prefix = term.substring(0, colonPos);
      final local = term.substring(colonPos + 1);
      final nsUri = prefixes[prefix];
      if (nsUri != null) {
        final full = '$nsUri$local';
        return stripSchemaPrefix(full);
      }
    }

    return term;
  }
}

String _ensureTrailingSlash(String s) {
  return s.endsWith('/') || s.endsWith('#') ? s : '$s/';
}

void _parsePrefixAttr(String attr, Map<String, String> prefixes) {
  final parts = attr.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
  for (var i = 0; i < parts.length - 1; i += 2) {
    var prefix = parts[i];
    if (prefix.endsWith(':')) {
      prefix = prefix.substring(0, prefix.length - 1);
    }
    final uri = parts[i + 1];
    prefixes[prefix] = uri;
  }
}

class RdfaLiteExtractor {
  ExtractionOutput extract(String html) {
    final doc = html_parser.parse(html);
    return extractFromDocument(doc);
  }

  ExtractionOutput extractFromDocument(dom.Document doc) {
    final warnings = <ExtractionWarning>[];
    final nodes = <SchemaNode>[];

    const context = RdfaContext();

    for (final child in doc.children) {
      _walkDom(child, context, nodes, warnings, 0);
    }

    return ExtractionOutput(nodes: nodes, warnings: warnings);
  }

  void _walkDom(
    dom.Node node,
    RdfaContext parentCtx,
    List<SchemaNode> nodes,
    List<ExtractionWarning> warnings,
    int depth,
  ) {
    if (depth > maxDepth) return;

    if (node is! dom.Element) {
      for (final child in node.children) {
        _walkDom(child, parentCtx, nodes, warnings, depth);
      }
      return;
    }

    final el = node;
    final updatedCtx = parentCtx.updated(el);
    final ctx = updatedCtx ?? parentCtx;

    if (el.attributes.containsKey('typeof')) {
      final typeofAttr = el.attributes['typeof']!;
      final types = typeofAttr
          .split(RegExp(r'\s+'))
          .where((s) => s.isNotEmpty)
          .map((t) => ctx.resolveTerm(t))
          .toList();

      if (types.isEmpty) {
        warnings.add(const ExtractionWarning(
          message: 'RDFa typeof attribute is empty',
          sourceLocation: null,
          code: WarningCode.emptyType,
        ));
      }

      final properties = <String, List<SchemaValue>>{};

      final resource = el.attributes['resource'];
      if (resource != null) {
        properties['@id'] = [classifyTextValue(resource)];
      }

      _collectRdfaProperties(el, ctx, properties, warnings, depth + 1);

      final schemaNode = SchemaNode(
        types: types,
        properties: properties,
        sourceFormat: SourceFormat.rdfaLite,
        sourceLocation: null,
      );

      nodes.add(schemaNode);
      return;
    }

    for (final child in el.children) {
      _walkDom(child, ctx, nodes, warnings, depth + 1);
    }
  }

  void _collectRdfaProperties(
    dom.Element element,
    RdfaContext ctx,
    Map<String, List<SchemaValue>> properties,
    List<ExtractionWarning> warnings,
    int depth,
  ) {
    if (depth > maxDepth) return;

    for (final child in element.children) {
      _visitForRdfaProps(child, ctx, properties, warnings, depth);
    }
  }

  void _visitForRdfaProps(
    dom.Element el,
    RdfaContext parentCtx,
    Map<String, List<SchemaValue>> properties,
    List<ExtractionWarning> warnings,
    int depth,
  ) {
    if (depth > maxDepth) return;

    final updatedCtx = parentCtx.updated(el);
    final ctx = updatedCtx ?? parentCtx;

    if (el.attributes.containsKey('property')) {
      final propAttr = el.attributes['property']!;
      final propNames = propAttr
          .split(RegExp(r'\s+'))
          .where((s) => s.isNotEmpty)
          .map((p) => ctx.resolveTerm(p))
          .toList();

      if (propNames.isEmpty) return;

      if (el.attributes.containsKey('typeof')) {
        final typeofAttr = el.attributes['typeof']!;
        final types = typeofAttr
            .split(RegExp(r'\s+'))
            .where((s) => s.isNotEmpty)
            .map((t) => ctx.resolveTerm(t))
            .toList();

        final nestedProps = <String, List<SchemaValue>>{};

        final resource = el.attributes['resource'];
        if (resource != null) {
          nestedProps['@id'] = [classifyTextValue(resource)];
        }

        _collectRdfaProperties(el, ctx, nestedProps, warnings, depth + 1);

        final nestedNode = SchemaNode(
          types: types,
          properties: nestedProps,
          sourceFormat: SourceFormat.rdfaLite,
          sourceLocation: null,
        );

        final val = SchemaValueNode(nestedNode);
        for (final name in propNames) {
          properties.putIfAbsent(name, () => []).add(val);
        }
        return;
      }

      final value = _extractRdfaValue(el);

      for (final name in propNames) {
        properties.putIfAbsent(name, () => []).add(value);
      }
      return;
    }

    if (el.attributes.containsKey('typeof')) {
      return;
    }

    for (final child in el.children) {
      _visitForRdfaProps(child, ctx, properties, warnings, depth + 1);
    }
  }

  SchemaValue _extractRdfaValue(dom.Element el) {
    final tag = el.localName?.toLowerCase() ?? '';

    final content = el.attributes['content'];
    if (content != null) {
      return classifyTextValue(content);
    }

    final resource = el.attributes['resource'];
    if (resource != null) {
      return classifyTextValue(resource);
    }

    final href = el.attributes['href'];
    if (href != null) {
      if (tag == 'a' || tag == 'link' || tag == 'area') {
        return SchemaValueUrl(href);
      }
      return classifyTextValue(href);
    }

    final src = el.attributes['src'];
    if (src != null) {
      if (tag == 'img' || tag == 'audio' || tag == 'video' || tag == 'source' || tag == 'embed') {
        return SchemaValueUrl(src);
      }
      return classifyTextValue(src);
    }

    if (tag == 'time') {
      final datetime = el.attributes['datetime'];
      if (datetime != null) {
        return SchemaValueDateTime(datetime);
      }
    }

    if (tag == 'data') {
      final valueAttr = el.attributes['value'];
      if (valueAttr != null) {
        return classifyTextValue(valueAttr);
      }
    }

    final trimmed = el.text.trim();
    return classifyTextValue(trimmed);
  }
}
