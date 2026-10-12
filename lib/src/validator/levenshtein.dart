const int maxDistance = 3;
const int maxLengthDiff = 3;

/// Suggests the closest match from a list of candidates using Levenshtein distance.
String? suggestSimilar(String input, List<String> candidates) {
  final inputLen = input.length;

  String? bestCandidate;
  var minDistance = maxDistance + 1;

  for (final candidate in candidates) {
    final candLen = candidate.length;
    final lenDiff = candidate.length > inputLen
        ? candLen - inputLen
        : inputLen - candLen;

    if (lenDiff > maxLengthDiff) continue;

    final dist = levenshtein(input, candidate);
    if (dist > 0 && dist <= maxDistance && dist < minDistance) {
      minDistance = dist;
      bestCandidate = candidate;
    }
  }

  return bestCandidate;
}

/// Computes the Levenshtein edit distance between two strings.
int levenshtein(String a, String b) {
  final aLen = a.length;
  final bLen = b.length;

  if (aLen == 0) return bLen;
  if (bLen == 0) return aLen;

  final aUnits = a.toLowerCase().codeUnits;
  final bUnits = b.toLowerCase().codeUnits;

  final row = List<int>.generate(bUnits.length + 1, (i) => i);

  for (var i = 0; i < aUnits.length; i++) {
    var prev = i;
    row[0] = i + 1;

    for (var j = 0; j < bUnits.length; j++) {
      final cost = aUnits[i] == bUnits[j] ? 0 : 1;
      final val = [row[j + 1] + 1, row[j] + 1, prev + cost].reduce((m, x) => x < m ? x : m);
      prev = row[j + 1];
      row[j + 1] = val;
    }
  }

  return row[bUnits.length];
}
