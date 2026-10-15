import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:schemaorg_validate/schemaorg_validate.dart';
import 'package:test/test.dart';

void main() {
  group('Value Equality Tests', () {
    test('SchemaNode equality and hashCode', () {
      final node1 = SchemaNode(
        types: ['Product'],
        properties: {
          'name': [const SchemaValueText('Widget')],
          'price': [const SchemaValueNumber(29.99)],
        },
        sourceFormat: SourceFormat.jsonLd,
      );

      final node2 = SchemaNode(
        types: ['Product'],
        properties: {
          'name': [const SchemaValueText('Widget')],
          'price': [const SchemaValueNumber(29.99)],
        },
        sourceFormat: SourceFormat.jsonLd,
      );

      final node3 = SchemaNode(
        types: ['Product'],
        properties: {
          'name': [const SchemaValueText('Gadget')],
        },
        sourceFormat: SourceFormat.jsonLd,
      );

      expect(node1, equals(node2));
      expect(node1.hashCode, equals(node2.hashCode));
      expect(node1, isNot(equals(node3)));
    });

    test('SchemaNode toJson and fromJson roundtrip', () {
      final node = SchemaNode(
        types: ['Product'],
        properties: {
          'name': [const SchemaValueText('Widget')],
          'url': [const SchemaValueUrl('https://example.com/widget')],
          'isAvailable': [const SchemaValueBoolean(true)],
          'price': [const SchemaValueNumber(19.99)],
          'offers': [
            SchemaValueNode(
              SchemaNode(
                types: ['Offer'],
                properties: {
                  'priceCurrency': [const SchemaValueText('USD')],
                },
                sourceFormat: SourceFormat.jsonLd,
              ),
            ),
          ],
        },
        sourceFormat: SourceFormat.jsonLd,
      );

      final jsonMap = node.toJson();
      final roundtripNode = SchemaNode.fromJson(jsonMap);

      expect(roundtripNode, equals(node));
    });

    test('StructuredDataGraph equality and toJson/fromJson roundtrip', () {
      final node = SchemaNode(
        types: ['Article'],
        properties: {
          'headline': [const SchemaValueText('News Title')],
        },
        sourceFormat: SourceFormat.jsonLd,
      );

      final warning = const ExtractionWarning(
        message: 'Sample warning',
        code: WarningCode.emptyType,
      );

      final graph1 = StructuredDataGraph(
        nodes: [node],
        warnings: [warning],
      );

      final graph2 = StructuredDataGraph(
        nodes: [
          SchemaNode(
            types: ['Article'],
            properties: {
              'headline': [const SchemaValueText('News Title')],
            },
            sourceFormat: SourceFormat.jsonLd,
          ),
        ],
        warnings: [warning],
      );

      expect(graph1, equals(graph2));
      expect(graph1.hashCode, equals(graph2.hashCode));

      final jsonList = graph1.toJson();
      final roundtripGraph = StructuredDataGraph.fromJson(
        jsonList,
        warnings: [warning],
      );
      expect(roundtripGraph, equals(graph1));
    });
  });

  group('JSON Schema Generation & Validation with json_schema_builder', () {
    test('SchemaNode.toJsonSchema generates valid Schema and validates JSON', () async {
      final node = SchemaNode(
        types: ['Product'],
        properties: {
          'name': [const SchemaValueText('Super Widget')],
          'price': [const SchemaValueNumber(99.99)],
        },
        sourceFormat: SourceFormat.jsonLd,
      );

      final schema = node.toJsonSchema();
      expect(schema, isA<Schema>());

      final validData = {
        '@context': 'https://schema.org',
        '@type': 'Product',
        'name': 'Super Widget',
        'price': 99.99,
      };

      final errors = schema.validateSync(validData);
      expect(errors, isEmpty);

      final extensionErrors = node.validateJson(validData);
      expect(extensionErrors, isEmpty);
    });

    test('StructuredDataGraph.toJsonSchema validates extracted graph JSON', () {
      const html = '''
        <script type="application/ld+json">
        {
          "@context": "https://schema.org",
          "@type": "Product",
          "name": "Widget Pro",
          "description": "High quality widget"
        }
        </script>
      ''';

      final graph = extractAll(html);
      final schema = graph.toJsonSchema();

      final jsonList = graph.toJson();
      final errors = schema.validateSync(jsonList);
      expect(errors, isEmpty);
    });

    test('SchemaOrgJsonSchemaBuilder.schemaTypeToJsonSchema for Genkit structured schemas', () async {
      final productSchema = SchemaOrgJsonSchemaBuilder.schemaTypeToJsonSchema('Product');

      expect(productSchema.value['title'], equals('Product'));
      expect(productSchema.value['properties'], isA<Map<String, dynamic>>());

      final sampleProduct = {
        '@context': 'https://schema.org',
        '@type': 'Product',
        'name': 'Genkit Compatible Product',
        'description': 'A product output from an LLM prompt',
      };

      final errors = await productSchema.validate(sampleProduct);
      expect(errors, isEmpty);
    });

    test('Profile.toJsonSchema generates schema for Google Rich Results profiles', () {
      final profile = GoogleArticleProfile();
      final schema = profile.toJsonSchema(
        requiredProperties: ['headline', 'image'],
      );

      final validArticle = {
        '@context': 'https://schema.org',
        '@type': 'Article',
        'headline': 'Breaking News',
        'image': 'https://example.com/image.jpg',
      };

      final validErrors = schema.validateSync(validArticle);
      expect(validErrors, isEmpty);

      final invalidArticle = {
        '@context': 'https://schema.org',
        '@type': 'Article',
        // missing headline and image
      };

      final invalidErrors = schema.validateSync(invalidArticle);
      expect(invalidErrors, isNotEmpty);
    });
  });
}
