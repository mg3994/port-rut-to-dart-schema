/// Definition of a Schema.org type (e.g. `Product`, `Article`).
class TypeDef {
  final String name;
  final List<String> parentTypes;
  final List<String> ownProperties;
  final List<String> allProperties;
  final String comment;
  final bool isPending;
  final bool isAttic;

  const TypeDef({
    required this.name,
    required this.parentTypes,
    required this.ownProperties,
    required this.allProperties,
    required this.comment,
    required this.isPending,
    required this.isAttic,
  });

  /// Checks if this type (or any parent type) defines the given property.
  bool hasProperty(String propName) => allProperties.contains(propName);
}

/// Definition of a Schema.org property (e.g. `price`, `offers`).
class PropertyDef {
  final String name;
  final List<String> expectedTypes;
  final List<String> domainTypes;
  final bool isSuperseded;
  final String? supersededBy;
  final bool isPending;

  const PropertyDef({
    required this.name,
    required this.expectedTypes,
    required this.domainTypes,
    required this.isSuperseded,
    this.supersededBy,
    required this.isPending,
  });
}

/// Definition of a Schema.org enumeration member (e.g. `InStock`, `Discontinued`).
class EnumMemberDef {
  final String name;
  final String enumType;

  const EnumMemberDef({
    required this.name,
    required this.enumType,
  });
}
