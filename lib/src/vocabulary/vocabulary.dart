import 'generated.dart' as generated;

export 'generated.dart'
    show
        lookupType,
        lookupProperty,
        lookupEnumMember,
        schemaVersion,
        allTypeNames,
        allPropertyNames;
export 'types.dart';

/// Checks if `childType` is a subtype of `ancestorType` by walking
/// the Schema.org type hierarchy.
bool isSubtype(String childType, String ancestorType) {
  if (childType == ancestorType) return false;
  final childDef = generated.lookupType(childType);
  if (childDef == null) return false;

  final queue = List<String>.from(childDef.parentTypes);
  final visited = <String>{};

  while (queue.isNotEmpty) {
    final current = queue.removeLast();
    if (current == ancestorType) {
      return true;
    }
    if (!visited.add(current)) {
      continue;
    }
    final td = generated.lookupType(current);
    if (td != null) {
      queue.addAll(td.parentTypes);
    }
  }
  return false;
}
