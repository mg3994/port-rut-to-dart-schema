import 'source_format.dart';
import 'source_location.dart';
import 'schema_value.dart';

/// A single structured data node (e.g. a Product, an Offer).
class SchemaNode {
  /// Schema.org type(s), e.g. ["Product", "IndividualProduct"].
  final List<String> types;

  /// Properties: key -> list of values (insertion-ordered).
  final Map<String, List<SchemaValue>> properties;

  /// Source format that this node was extracted from.
  final SourceFormat sourceFormat;

  /// Location in the original HTML document.
  final SourceLocation? sourceLocation;

  SchemaNode({
    required this.types,
    required this.properties,
    required this.sourceFormat,
    this.sourceLocation,
  });

  /// Returns the `@id` of this node, if present.
  String? get id {
    final vals = properties['@id'];
    if (vals == null || vals.isEmpty) return null;
    final first = vals.first;
    if (first is SchemaValueText) return first.value;
    if (first is SchemaValueUrl) return first.value;
    return null;
  }

  /// Converts this [SchemaNode] to a standard JSON-compatible Map.
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (types.isNotEmpty) {
      map['@type'] = types.length == 1 ? types.first : List<String>.from(types);
    }
    for (final entry in properties.entries) {
      final key = entry.key;
      final vals = entry.value;
      if (vals.isEmpty) continue;
      if (vals.length == 1) {
        map[key] = vals.first.toJson();
      } else {
        map[key] = vals.map((v) => v.toJson()).toList();
      }
    }
    return map;
  }

  /// Deserializes a JSON map into a [SchemaNode].
  factory SchemaNode.fromJson(
    Map<String, dynamic> json, {
    SourceFormat sourceFormat = SourceFormat.jsonLd,
    SourceLocation? sourceLocation,
  }) {
    final types = <String>[];
    final rawType = json['@type'] ?? json['type'];
    if (rawType is String) {
      types.add(rawType);
    } else if (rawType is List) {
      types.addAll(rawType.map((e) => e.toString()));
    }

    final properties = <String, List<SchemaValue>>{};
    for (final entry in json.entries) {
      final key = entry.key;
      if (key == '@type' || key == 'type') continue;
      final val = entry.value;
      if (val == null) continue;

      final valuesList = <SchemaValue>[];
      if (val is List) {
        for (final item in val) {
          if (item != null) {
            valuesList.add(SchemaValue.fromJson(item));
          }
        }
      } else {
        valuesList.add(SchemaValue.fromJson(val));
      }
      properties[key] = valuesList;
    }

    return SchemaNode(
      types: types,
      properties: properties,
      sourceFormat: sourceFormat,
      sourceLocation: sourceLocation,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SchemaNode) return false;
    if (types.length != other.types.length) return false;
    for (var i = 0; i < types.length; i++) {
      if (types[i] != other.types[i]) return false;
    }
    if (sourceFormat != other.sourceFormat) return false;
    if (sourceLocation != other.sourceLocation) return false;
    if (properties.length != other.properties.length) return false;
    for (final entry in properties.entries) {
      final otherVals = other.properties[entry.key];
      if (otherVals == null || otherVals.length != entry.value.length) {
        return false;
      }
      for (var i = 0; i < entry.value.length; i++) {
        if (entry.value[i] != otherVals[i]) return false;
      }
    }
    return true;
  }

  @override
  int get hashCode {
    return Object.hash(
      Object.hashAll(types),
      sourceFormat,
      sourceLocation,
      Object.hashAll(
        properties.entries.map((e) => Object.hash(e.key, Object.hashAll(e.value))),
      ),
    );
  }

  @override
  String toString() {
    return 'SchemaNode(types: $types, properties: ${properties.keys.toList()}, sourceFormat: $sourceFormat)';
  }
}
