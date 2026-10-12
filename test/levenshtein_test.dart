import 'package:schemaorg_validate/src/validator/levenshtein.dart';
import 'package:test/test.dart';

void main() {
  group('Levenshtein distance & suggestions', () {
    test('levenshtein basic distance', () {
      expect(levenshtein('', ''), equals(0));
      expect(levenshtein('a', ''), equals(1));
      expect(levenshtein('', 'a'), equals(1));
      expect(levenshtein('kitten', 'sitting'), equals(3));
      expect(levenshtein('Product', 'Produc'), equals(1));
      expect(levenshtein('Product', 'product'), equals(0)); // case-insensitive
      expect(levenshtein('name', 'namee'), equals(1));
    });

    test('suggestSimilar finds close match', () {
      const candidates = ['Product', 'Person', 'Place', 'Event'];
      expect(suggestSimilar('Produc', candidates), equals('Product'));
      expect(suggestSimilar('Prduct', candidates), equals('Product'));
      expect(suggestSimilar('Perso', candidates), equals('Person'));
    });

    test('suggestSimilar returns null for distant strings', () {
      const candidates = ['Product', 'Person', 'Place'];
      expect(suggestSimilar('XYZ123', candidates), isNull);
    });

    test('suggestSimilar returns null for exact match', () {
      const candidates = ['Product', 'Person'];
      expect(suggestSimilar('Product', candidates), isNull);
    });
  });
}
