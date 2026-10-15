import 'package:json_schema_builder/json_schema_builder.dart';

import '../models/schema_node.dart';
import '../models/schema_value.dart';
import '../parser/html_extractor.dart';
import '../rich_results/profile_interface.dart';
import '../vocabulary/vocabulary.dart';

/// Configuration options for JSON Schema generation.
class JsonSchemaOptions {
  /// Whether to disallow additional properties not explicitly specified in the schema.
  final bool strict;

  /// Whether to require the `@type` field in generated object schemas.
  final bool requireType;

  /// Whether to include `@context` as an optional or required property in the schema.
  final bool includeContext;

  /// Default `@context` value string (e.g. "https://schema.org").
  final String? contextValue;

  /// Whether properties that accept a type can also be specified as a list/array.
  final bool allowArrayValues;

  const JsonSchemaOptions({
    this.strict = false,
    this.requireType = true,
    this.includeContext = true,
    this.contextValue = 'https://schema.org',
    this.allowArrayValues = true,
  });
}

/// Helper class to build Draft 2020-12 compliant JSON Schemas using [json_schema_builder]
/// for Schema.org nodes, graphs, vocabulary types, and rich results profiles.
class SchemaOrgJsonSchemaBuilder {
  /// Creates a schema for `anyOf` sub-schemas.
  static Schema anyOf(List<Schema> schemas, {String? title, String? description}) {
    return Schema.fromMap({
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      'anyOf': schemas.map((s) => s.value).toList(),
    });
  }

  /// Creates a schema for `oneOf` sub-schemas.
  static Schema oneOf(List<Schema> schemas, {String? title, String? description}) {
    return Schema.fromMap({
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      'oneOf': schemas.map((s) => s.value).toList(),
    });
  }

  /// Creates a schema for `allOf` sub-schemas.
  static Schema allOf(List<Schema> schemas, {String? title, String? description}) {
    return Schema.fromMap({
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      'allOf': schemas.map((s) => s.value).toList(),
    });
  }

  /// Converts a [SchemaNode] into a `json_schema_builder` [Schema].
  static Schema schemaNodeToJsonSchema(
    SchemaNode node, {
    JsonSchemaOptions options = const JsonSchemaOptions(),
  }) {
    final properties = <String, Schema>{};
    final requiredProps = <String>[];

    if (options.includeContext) {
      if (options.contextValue != null) {
        properties['@context'] = S.string(enumValues: [options.contextValue!]);
      } else {
        properties['@context'] = S.string();
      }
    }

    if (node.types.isNotEmpty) {
      if (node.types.length == 1) {
        properties['@type'] = S.string(enumValues: [node.types.first]);
      } else {
        properties['@type'] = anyOf([
          S.string(enumValues: node.types),
          S.list(items: S.string(enumValues: node.types)),
        ]);
      }
      if (options.requireType) {
        requiredProps.add('@type');
      }
    }

    for (final entry in node.properties.entries) {
      final propName = entry.key;
      final values = entry.value;
      if (values.isEmpty) continue;

      Schema propSchema;
      if (values.length == 1) {
        propSchema = _schemaValueToJsonSchema(values.first, options: options);
      } else {
        final valueSchemas = values
            .map((v) => _schemaValueToJsonSchema(v, options: options))
            .toList();
        propSchema = S.list(items: anyOf(valueSchemas));
      }

      if (options.allowArrayValues && values.length == 1) {
        propSchema = anyOf([
          propSchema,
          S.list(items: propSchema),
        ]);
      }

      properties[propName] = propSchema;
    }

    return S.object(
      title: node.types.isNotEmpty ? node.types.join('/') : 'SchemaNode',
      description: 'JSON Schema generated from SchemaNode',
      properties: properties,
      required: requiredProps.isNotEmpty ? requiredProps : null,
      additionalProperties: !options.strict,
    );
  }

  /// Converts a [StructuredDataGraph] into a `json_schema_builder` [Schema].
  static Schema graphToJsonSchema(
    StructuredDataGraph graph, {
    JsonSchemaOptions options = const JsonSchemaOptions(),
  }) {
    if (graph.nodes.isEmpty) {
      return S.list(
        title: 'StructuredDataGraph',
        description: 'Empty structured data graph',
      );
    }

    final nodeSchemas = graph.nodes
        .map((n) => schemaNodeToJsonSchema(n, options: options))
        .toList();

    return S.list(
      title: 'StructuredDataGraph',
      description: 'JSON Schema for extracted structured data graph',
      items: nodeSchemas.length == 1 ? nodeSchemas.first : anyOf(nodeSchemas),
    );
  }

  /// Generates a `json_schema_builder` [Schema] for a given Schema.org type (e.g. "Product", "Article")
  /// based on the vocabulary definitions.
  static Schema schemaTypeToJsonSchema(
    String typeName, {
    JsonSchemaOptions options = const JsonSchemaOptions(),
  }) {
    final typeDef = lookupType(typeName);
    if (typeDef == null) {
      return S.object(
        title: typeName,
        description: 'Unknown Schema.org type: $typeName',
        properties: {
          '@type': S.string(enumValues: [typeName]),
        },
        required: options.requireType ? ['@type'] : null,
        additionalProperties: !options.strict,
      );
    }

    final properties = <String, Schema>{};

    if (options.includeContext) {
      if (options.contextValue != null) {
        properties['@context'] = S.string(enumValues: [options.contextValue!]);
      } else {
        properties['@context'] = S.string();
      }
    }

    properties['@type'] = S.string(enumValues: [typeName]);

    for (final propName in typeDef.allProperties) {
      final propDef = lookupProperty(propName);
      if (propDef != null) {
        final propSchema = _propertyDefToJsonSchema(propDef, options: options);
        properties[propName] = propSchema;
      }
    }

    return S.object(
      title: typeDef.name,
      description: typeDef.comment.isNotEmpty ? typeDef.comment : 'Schema.org ${typeDef.name}',
      properties: properties,
      required: options.requireType ? ['@type'] : null,
      additionalProperties: !options.strict,
    );
  }

  /// Generates a `json_schema_builder` [Schema] for a Google Rich Result [Profile].
  static Schema profileToJsonSchema(
    Profile profile, {
    JsonSchemaOptions options = const JsonSchemaOptions(),
    List<String>? requiredProperties,
  }) {
    final properties = <String, Schema>{};

    if (options.includeContext) {
      if (options.contextValue != null) {
        properties['@context'] = S.string(enumValues: [options.contextValue!]);
      } else {
        properties['@context'] = S.string();
      }
    }

    if (profile.supportedTypes.isNotEmpty) {
      properties['@type'] = S.string(enumValues: profile.supportedTypes);
    }

    final requiredList = <String>[];
    if (options.requireType && profile.supportedTypes.isNotEmpty) {
      requiredList.add('@type');
    }
    if (requiredProperties != null) {
      requiredList.addAll(requiredProperties);
    }

    return S.object(
      title: profile.name,
      description: 'JSON Schema for ${profile.name} (v${profile.version})',
      properties: properties,
      required: requiredList.isNotEmpty ? requiredList : null,
      additionalProperties: !options.strict,
    );
  }

  static Schema _schemaValueToJsonSchema(
    SchemaValue value, {
    required JsonSchemaOptions options,
  }) {
    return switch (value) {
      SchemaValueText() => S.string(),
      SchemaValueUrl() => S.string(format: 'uri'),
      SchemaValueBoolean() => S.boolean(),
      SchemaValueNumber() => S.number(),
      SchemaValueDateTime() => S.string(format: 'date-time'),
      SchemaValueNode(:final node) => schemaNodeToJsonSchema(node, options: options),
    };
  }

  static Schema _propertyDefToJsonSchema(
    PropertyDef propDef, {
    required JsonSchemaOptions options,
  }) {
    if (propDef.expectedTypes.isEmpty) {
      final base = S.string();
      return options.allowArrayValues ? anyOf([base, S.list(items: base)]) : base;
    }

    final subSchemas = <Schema>[];
    for (final expType in propDef.expectedTypes) {
      switch (expType) {
        case 'Text':
          subSchemas.add(S.string());
        case 'URL':
          subSchemas.add(S.string(format: 'uri'));
        case 'Number':
        case 'Float':
          subSchemas.add(S.number());
        case 'Integer':
          subSchemas.add(S.integer());
        case 'Boolean':
          subSchemas.add(S.boolean());
        case 'Date':
          subSchemas.add(S.string(format: 'date'));
        case 'DateTime':
          subSchemas.add(S.string(format: 'date-time'));
        case 'Time':
          subSchemas.add(S.string(format: 'time'));
        default:
          subSchemas.add(anyOf([
            S.object(
              properties: {
                '@type': S.string(enumValues: [expType]),
              },
              additionalProperties: true,
            ),
            S.string(),
          ]));
      }
    }

    final singleSchema = subSchemas.length == 1 ? subSchemas.first : anyOf(subSchemas);
    if (options.allowArrayValues) {
      return anyOf([
        singleSchema,
        S.list(items: singleSchema),
      ]);
    }
    return singleSchema;
  }
}

/// Extension methods for convenient JSON Schema generation and validation.
extension SchemaNodeJsonSchemaExtension on SchemaNode {
  /// Converts this [SchemaNode] to a `json_schema_builder` [Schema].
  Schema toJsonSchema({JsonSchemaOptions options = const JsonSchemaOptions()}) {
    return SchemaOrgJsonSchemaBuilder.schemaNodeToJsonSchema(this, options: options);
  }

  /// Validates a raw JSON map against the schema derived from this node.
  List<ValidationError> validateJson(
    Map<String, dynamic> json, {
    JsonSchemaOptions options = const JsonSchemaOptions(),
  }) {
    final schema = toJsonSchema(options: options);
    return schema.validateSync(json);
  }
}

extension StructuredDataGraphJsonSchemaExtension on StructuredDataGraph {
  /// Converts this [StructuredDataGraph] to a `json_schema_builder` [Schema].
  Schema toJsonSchema({JsonSchemaOptions options = const JsonSchemaOptions()}) {
    return SchemaOrgJsonSchemaBuilder.graphToJsonSchema(this, options: options);
  }

  /// Validates a list of JSON maps against the schema derived from this graph.
  List<ValidationError> validateJson(
    List<dynamic> jsonList, {
    JsonSchemaOptions options = const JsonSchemaOptions(),
  }) {
    final schema = toJsonSchema(options: options);
    return schema.validateSync(jsonList);
  }
}

extension ProfileJsonSchemaExtension on Profile {
  /// Converts this [Profile] to a `json_schema_builder` [Schema].
  Schema toJsonSchema({
    JsonSchemaOptions options = const JsonSchemaOptions(),
    List<String>? requiredProperties,
  }) {
    return SchemaOrgJsonSchemaBuilder.profileToJsonSchema(
      this,
      options: options,
      requiredProperties: requiredProperties,
    );
  }
}
