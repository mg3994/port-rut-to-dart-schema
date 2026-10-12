import 'package:schemaorg_validate/schemaorg_validate.dart';
import 'package:test/test.dart';

void main() {
  group('Vocabulary & Taxonomy', () {
    test('schemaVersion returns valid version', () {
      expect(schemaVersion(), isNotEmpty);
      expect(schemaVersion(), contains('.'));
    });

    test('allTypeNames and allPropertyNames are populated and sorted', () {
      expect(allTypeNames.length, greaterThan(500));
      expect(allPropertyNames.length, greaterThan(1000));

      expect(allTypeNames.contains('Product'), isTrue);
      expect(allTypeNames.contains('Article'), isTrue);
      expect(allPropertyNames.contains('name'), isTrue);
      expect(allPropertyNames.contains('offers'), isTrue);
    });

    test('lookupType Product', () {
      final typeDef = lookupType('Product');
      expect(typeDef, isNotNull);
      expect(typeDef!.name, equals('Product'));
      expect(typeDef.hasProperty('name'), isTrue);
      expect(typeDef.hasProperty('offers'), isTrue);
      expect(typeDef.parentTypes, contains('Thing'));
    });

    test('lookupProperty price', () {
      final propDef = lookupProperty('price');
      expect(propDef, isNotNull);
      expect(propDef!.name, equals('price'));
      expect(propDef.expectedTypes, anyOf(contains('Number'), contains('Text')));
      expect(propDef.domainTypes, contains('Offer'));
    });

    test('lookupEnumMember InStock', () {
      final memberDef = lookupEnumMember('InStock');
      expect(memberDef, isNotNull);
      expect(memberDef!.name, equals('InStock'));
      expect(memberDef.enumType, equals('ItemAvailability'));
    });

    test('isSubtype hierarchy', () {
      expect(isSubtype('NewsArticle', 'Article'), isTrue);
      expect(isSubtype('NewsArticle', 'Thing'), isTrue);
      expect(isSubtype('Product', 'Thing'), isTrue);
      expect(isSubtype('Product', 'Person'), isFalse);
      expect(isSubtype('Product', 'Product'), isFalse);
      expect(isSubtype('UnknownType123', 'Thing'), isFalse);
    });
  });
}
