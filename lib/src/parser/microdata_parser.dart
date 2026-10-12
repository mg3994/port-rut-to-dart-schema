import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../models/extraction_warning.dart';
import '../models/schema_node.dart';
import '../models/schema_value.dart';
import '../models/source_format.dart';
import 'common.dart';
import 'jsonld_parser.dart' show ExtractionOutput;

const int maxDepth = 20;

class MicrodataExtractor {
  ExtractionOutput extract(String html) {
    final doc = html_parser.parse(html);
    return extractFromDocument(doc);
  }

  ExtractionOutput extractFromDocument(dom.Document doc) {
    final warnings = <ExtractionWarning>[];
    final nodes = <SchemaNode>[];

    final elementsWithItemscope = doc.querySelectorAll('[itemscope]');

    for (final element in elementsWithItemscope) {
      if (element.attributes.containsKey('itemprop')) {
        continue;
      }

      final item = _extractItem(element, doc, warnings, 0);
      if (item != null) {
        nodes.add(item);
      } else {
        warnings.add(const ExtractionWarning(
          message: 'failed to extract Microdata item',
          sourceLocation: null,
          code: WarningCode.malformedMicrodata,
        ));
      }
    }

    return ExtractionOutput(nodes: nodes, warnings: warnings);
  }

  SchemaNode? _extractItem(
    dom.Element element,
    dom.Document doc,
    List<ExtractionWarning> warnings,
    int depth,
  ) {
    if (depth > maxDepth) {
      warnings.add(const ExtractionWarning(
        message: 'Microdata nesting depth exceeds 20, skipping',
        sourceLocation: null,
        code: WarningCode.malformedMicrodata,
      ));
      return null;
    }

    final types = _extractItemtypes(element);
    final properties = <String, List<SchemaValue>>{};

    final itemId = element.attributes['itemid'];
    if (itemId != null) {
      properties['@id'] = [classifyTextValue(itemId)];
    }

    _collectProperties(element, doc, warnings, properties, depth);

    final itemref = element.attributes['itemref'];
    if (itemref != null) {
      for (final refId in itemref.split(RegExp(r'\s+'))) {
        if (refId.isEmpty) continue;
        final target = doc.getElementById(refId);
        if (target != null) {
          if (target.attributes.containsKey('itemprop')) {
            _extractPropValue(target, doc, warnings, properties, depth);
          } else {
            _collectProperties(target, doc, warnings, properties, depth);
          }
        } else {
          warnings.add(ExtractionWarning(
            message: 'itemref target not found: #$refId',
            sourceLocation: null,
            code: WarningCode.unresolvableReference,
          ));
        }
      }
    }

    if (types.isEmpty && properties.isEmpty) {
      return null;
    }

    if (types.isEmpty) {
      warnings.add(const ExtractionWarning(
        message: 'Microdata item has itemscope but no itemtype',
        sourceLocation: null,
        code: WarningCode.emptyType,
      ));
    }

    return SchemaNode(
      types: types,
      properties: properties,
      sourceFormat: SourceFormat.microdata,
      sourceLocation: null,
    );
  }

  void _collectProperties(
    dom.Element element,
    dom.Document doc,
    List<ExtractionWarning> warnings,
    Map<String, List<SchemaValue>> properties,
    int depth,
  ) {
    for (final child in element.children) {
      _visitForProperties(child, doc, warnings, properties, depth);
    }
  }

  void _visitForProperties(
    dom.Element element,
    dom.Document doc,
    List<ExtractionWarning> warnings,
    Map<String, List<SchemaValue>> properties,
    int depth,
  ) {
    if (element.attributes.containsKey('itemprop')) {
      _extractPropValue(element, doc, warnings, properties, depth);
      return;
    }

    if (element.attributes.containsKey('itemscope')) {
      return;
    }

    for (final child in element.children) {
      _visitForProperties(child, doc, warnings, properties, depth);
    }
  }

  void _extractPropValue(
    dom.Element element,
    dom.Document doc,
    List<ExtractionWarning> warnings,
    Map<String, List<SchemaValue>> properties,
    int depth,
  ) {
    final itempropAttr = element.attributes['itemprop'] ?? '';
    final propNames = itempropAttr.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();

    if (propNames.isEmpty) return;

    final value = _extractElementValue(element, doc, warnings, depth);

    for (final name in propNames) {
      properties.putIfAbsent(name, () => []).add(value);
    }
  }

  SchemaValue _extractElementValue(
    dom.Element element,
    dom.Document doc,
    List<ExtractionWarning> warnings,
    int depth,
  ) {
    if (element.attributes.containsKey('itemscope')) {
      final node = _extractItem(element, doc, warnings, depth + 1);
      return node != null ? SchemaValueNode(node) : const SchemaValueText('');
    }

    final tag = element.localName?.toLowerCase() ?? '';

    switch (tag) {
      case 'meta':
        final content = element.attributes['content'] ?? '';
        return classifyTextValue(content);
      case 'a':
      case 'link':
      case 'area':
        final href = element.attributes['href'] ?? '';
        return href.isEmpty
            ? SchemaValueText(element.text.trim())
            : SchemaValueUrl(href);
      case 'img':
      case 'audio':
      case 'video':
      case 'source':
      case 'embed':
        final src = element.attributes['src'] ?? '';
        return src.isEmpty ? const SchemaValueText('') : SchemaValueUrl(src);
      case 'object':
        final data = element.attributes['data'] ?? '';
        return data.isEmpty ? const SchemaValueText('') : SchemaValueUrl(data);
      case 'time':
        final datetime = element.attributes['datetime'] ?? '';
        return datetime.isEmpty
            ? SchemaValueText(element.text.trim())
            : SchemaValueDateTime(datetime);
      case 'data':
        final val = element.attributes['value'] ?? '';
        return val.isEmpty
            ? SchemaValueText(element.text.trim())
            : classifyTextValue(val);
      case 'meter':
        final val = element.attributes['value'] ?? '';
        final n = num.tryParse(val);
        return n != null ? SchemaValueNumber(n) : SchemaValueText(val);
      default:
        final trimmed = element.text.trim();
        return classifyTextValue(trimmed);
    }
  }

  List<String> _extractItemtypes(dom.Element element) {
    final itemtype = element.attributes['itemtype'];
    if (itemtype == null) return [];
    return itemtype
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .map(stripSchemaPrefix)
        .toList();
  }
}
