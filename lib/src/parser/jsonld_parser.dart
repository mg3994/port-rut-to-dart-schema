import 'dart:convert';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../models/extraction_warning.dart';
import '../models/schema_node.dart';
import '../models/schema_value.dart';
import '../models/source_format.dart';
import '../models/source_location.dart';
import 'common.dart';

const int maxDepth = 20;
const int maxRefDepth = 10;
const int maxRefResolutions = 50;

class ExtractionOutput {
  final List<SchemaNode> nodes;
  final List<ExtractionWarning> warnings;

  ExtractionOutput({
    required this.nodes,
    required this.warnings,
  });
}

class LineIndex {
  final List<int> lineStarts;

  LineIndex(String text) : lineStarts = [0] {
    final units = text.codeUnits;
    for (var i = 0; i < units.length; i++) {
      if (units[i] == 10) {
        // \n
        lineStarts.add(i + 1);
      }
    }
  }

  SourceLocation location(int byteOffset) {
    var line = 0;
    while (line + 1 < lineStarts.length && lineStarts[line + 1] <= byteOffset) {
      line++;
    }
    final col = byteOffset - lineStarts[line];
    return SourceLocation(
      line: line + 1,
      column: col + 1,
      byteOffset: byteOffset,
    );
  }
}

List<int> findScriptByteOffsets(String html) {
  final offsets = <int>[];
  var searchFrom = 0;
  const pattern = 'application/ld+json';

  while (true) {
    final pos = html.indexOf(pattern, searchFrom);
    if (pos == -1) break;

    final tagStart = html.lastIndexOf('<', pos);
    if (tagStart != -1 && html.substring(tagStart, pos).contains('script')) {
      offsets.add(tagStart);
    }
    searchFrom = pos + pattern.length;
  }

  return offsets;
}

class JsonLdExtractor {
  ExtractionOutput extract(String html) {
    final doc = html_parser.parse(html);
    return extractFromDocument(doc, html);
  }

  ExtractionOutput extractFromDocument(dom.Document doc, String html) {
    final scripts = doc.querySelectorAll('script[type="application/ld+json"]');
    final lineIndex = LineIndex(html);
    final scriptOffsets = findScriptByteOffsets(html);

    final allNodes = <SchemaNode>[];
    final warnings = <ExtractionWarning>[];

    for (var idx = 0; idx < scripts.length; idx++) {
      final element = scripts[idx];
      final jsonText = element.text;
      final trimmed = jsonText.trim();
      final sourceLocation = idx < scriptOffsets.length
          ? lineIndex.location(scriptOffsets[idx])
          : null;

      if (trimmed.isEmpty) {
        warnings.add(ExtractionWarning(
          message: 'empty JSON-LD script tag',
          sourceLocation: sourceLocation,
          code: WarningCode.malformedJsonLd,
        ));
        continue;
      }

      dynamic decoded;
      try {
        decoded = jsonDecode(trimmed);
      } catch (e) {
        warnings.add(ExtractionWarning(
          message: 'failed to parse JSON-LD: $e',
          sourceLocation: sourceLocation,
          code: WarningCode.malformedJsonLd,
        ));
        continue;
      }

      final items = _extractJsonItems(decoded, sourceLocation, warnings);
      allNodes.addAll(items);
    }

    final idToIndex = <String, int>{};
    for (var i = 0; i < allNodes.length; i++) {
      final node = allNodes[i];
      final id = node.id;
      if (id != null) {
        if (idToIndex.containsKey(id)) {
          warnings.add(ExtractionWarning(
            message: 'duplicate @id: $id',
            sourceLocation: node.sourceLocation,
            code: WarningCode.duplicateId,
          ));
        } else {
          idToIndex[id] = i;
        }
      }
    }

    final referenced = _collectReferencedIds(allNodes);
    final idMap = <String, SchemaNode>{};
    for (final id in referenced) {
      final idx = idToIndex[id];
      if (idx != null) {
        idMap[id] = allNodes[idx];
      }
    }

    _resolveReferences(allNodes, idMap, warnings);

    return ExtractionOutput(nodes: allNodes, warnings: warnings);
  }

  List<SchemaNode> _extractJsonItems(
    dynamic value,
    SourceLocation? sourceLocation,
    List<ExtractionWarning> warnings,
  ) {
    if (value is List) {
      final result = <SchemaNode>[];
      for (final item in value) {
        final node = _jsonToNode(item, null, sourceLocation, warnings, 0);
        if (node != null) result.add(node);
      }
      return result;
    } else if (value is Map<String, dynamic>) {
      if (value.containsKey('@graph') && value['@graph'] is List) {
        final parentContext = value['@context'];
        final graphItems = value['@graph'] as List;
        final result = <SchemaNode>[];
        for (final item in graphItems) {
          final node = _jsonToNode(item, parentContext, sourceLocation, warnings, 0);
          if (node != null) result.add(node);
        }
        return result;
      } else {
        final node = _jsonToNode(value, null, sourceLocation, warnings, 0);
        return node != null ? [node] : [];
      }
    } else {
      warnings.add(ExtractionWarning(
        message: 'JSON-LD root must be an object or array',
        sourceLocation: sourceLocation,
        code: WarningCode.malformedJsonLd,
      ));
      return [];
    }
  }

  SchemaNode? _jsonToNode(
    dynamic value,
    dynamic parentContext,
    SourceLocation? sourceLocation,
    List<ExtractionWarning> warnings,
    int depth,
  ) {
    if (depth > maxDepth) {
      warnings.add(ExtractionWarning(
        message: 'JSON-LD nesting depth exceeds $maxDepth, skipping',
        sourceLocation: sourceLocation,
        code: WarningCode.malformedJsonLd,
      ));
      return null;
    }

    if (value is! Map<String, dynamic>) return null;

    final context = value['@context'] ?? parentContext;
    final types = _extractTypes(value);

    if (types.isEmpty) {
      final nonMetaKeys = value.keys.where((k) => !k.startsWith('@')).length;
      final isReference = value.containsKey('@id') && nonMetaKeys == 0;
      if (!isReference && value.isNotEmpty) {
        warnings.add(ExtractionWarning(
          message: 'JSON-LD object has no @type',
          sourceLocation: sourceLocation,
          code: WarningCode.emptyType,
        ));
      }
    }

    final properties = <String, List<SchemaValue>>{};

    for (final entry in value.entries) {
      final key = entry.key;
      final val = entry.value;

      if (key == '@context' || key == '@type') {
        continue;
      }

      if (key == '@id') {
        if (val is String) {
          properties.putIfAbsent(key, () => []).add(classifyTextValue(val));
        }
        continue;
      }

      final values = _jsonToSchemaValues(val, context, sourceLocation, warnings, depth);
      if (values.isNotEmpty) {
        properties.putIfAbsent(key, () => []).addAll(values);
      }
    }

    return SchemaNode(
      types: types,
      properties: properties,
      sourceFormat: SourceFormat.jsonLd,
      sourceLocation: sourceLocation,
    );
  }

  List<String> _extractTypes(Map<String, dynamic> obj) {
    final rawType = obj['@type'];
    if (rawType is String) {
      return [stripSchemaPrefix(rawType)];
    } else if (rawType is List) {
      final result = <String>[];
      for (final item in rawType) {
        if (item is String) {
          result.add(stripSchemaPrefix(item));
        }
      }
      return result;
    }
    return [];
  }

  List<SchemaValue> _jsonToSchemaValues(
    dynamic value,
    dynamic context,
    SourceLocation? sourceLocation,
    List<ExtractionWarning> warnings,
    int depth,
  ) {
    if (value == null) {
      return [];
    } else if (value is bool) {
      return [SchemaValueBoolean(value)];
    } else if (value is num) {
      return [SchemaValueNumber(value)];
    } else if (value is String) {
      return [classifyTextValue(value)];
    } else if (value is List) {
      final result = <SchemaValue>[];
      for (final item in value) {
        result.addAll(_jsonToSchemaValues(item, context, sourceLocation, warnings, depth));
      }
      return result;
    } else if (value is Map<String, dynamic>) {
      final node = _jsonToNode(value, context, sourceLocation, warnings, depth + 1);
      if (node != null) {
        return [SchemaValueNode(node)];
      }
    }
    return [];
  }

  Set<String> _collectReferencedIds(List<SchemaNode> nodes) {
    final refs = <String>{};
    for (final node in nodes) {
      _collectRefsInNode(node, refs, 0);
    }
    return refs;
  }

  void _collectRefsInNode(SchemaNode node, Set<String> refs, int depth) {
    if (depth > maxDepth) return;
    for (final values in node.properties.values) {
      for (final value in values) {
        if (value is SchemaValueNode) {
          final inner = value.node;
          if (inner.types.isEmpty) {
            final idValues = inner.properties['@id'];
            if (idValues != null && idValues.isNotEmpty) {
              final first = idValues.first;
              if (first is SchemaValueText) {
                refs.add(first.value);
                continue;
              } else if (first is SchemaValueUrl) {
                refs.add(first.value);
                continue;
              }
            }
          }
          _collectRefsInNode(inner, refs, depth + 1);
        }
      }
    }
  }

  void _resolveReferences(
    List<SchemaNode> nodes,
    Map<String, SchemaNode> idMap,
    List<ExtractionWarning> warnings,
  ) {
    var resolutionCount = 0;
    for (var i = 0; i < nodes.length; i++) {
      nodes[i] = _resolveNodeRefs(nodes[i], idMap, warnings, 0, () => resolutionCount, (val) => resolutionCount = val);
    }
  }

  SchemaNode _resolveNodeRefs(
    SchemaNode node,
    Map<String, SchemaNode> idMap,
    List<ExtractionWarning> warnings,
    int depth,
    int Function() getResCount,
    void Function(int) setResCount,
  ) {
    if (depth > maxRefDepth) return node;

    final newProperties = <String, List<SchemaValue>>{};

    for (final entry in node.properties.entries) {
      final newValues = <SchemaValue>[];
      for (final value in entry.value) {
        if (value is SchemaValueNode) {
          final inner = value.node;
          if (inner.types.isEmpty) {
            final idValues = inner.properties['@id'];
            if (idValues != null && idValues.isNotEmpty) {
              final first = idValues.first;
              final String? idStr = switch (first) {
                SchemaValueText(value: final v) => v,
                SchemaValueUrl(value: final v) => v,
                _ => null,
              };

              if (idStr != null) {
                if (getResCount() >= maxRefResolutions) {
                  newValues.add(value);
                  continue;
                }
                final resolved = idMap[idStr];
                if (resolved != null) {
                  final hasContent = resolved.types.isNotEmpty || resolved.properties.length > 1;
                  if (hasContent) {
                    setResCount(getResCount() + 1);
                    final resolvedNode = _resolveNodeRefs(resolved, idMap, warnings, depth + 1, getResCount, setResCount);
                    newValues.add(SchemaValueNode(resolvedNode));
                    continue;
                  }
                }

                if (idStr.startsWith('#')) {
                  warnings.add(ExtractionWarning(
                    message: 'unresolvable @id reference: $idStr',
                    sourceLocation: inner.sourceLocation,
                    code: WarningCode.unresolvableReference,
                  ));
                }
                newValues.add(value);
                continue;
              }
            }
          }
          final resolvedInner = _resolveNodeRefs(inner, idMap, warnings, depth + 1, getResCount, setResCount);
          newValues.add(SchemaValueNode(resolvedInner));
        } else {
          newValues.add(value);
        }
      }
      newProperties[entry.key] = newValues;
    }

    return SchemaNode(
      types: node.types,
      properties: newProperties,
      sourceFormat: node.sourceFormat,
      sourceLocation: node.sourceLocation,
    );
  }
}
