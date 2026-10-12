import 'dart:convert';
import 'dart:io';

class RawType {
  final String name;
  final List<String> parentNames;
  final Set<String> ownProperties = {};
  final String comment;
  final bool isPending;
  final bool isAttic;

  RawType({
    required this.name,
    required this.parentNames,
    required this.comment,
    required this.isPending,
    required this.isAttic,
  });
}

class RawProperty {
  final String name;
  final List<String> expectedTypes;
  final List<String> domainTypes;
  final bool isSuperseded;
  final String? supersededBy;
  final bool isPending;

  RawProperty({
    required this.name,
    required this.expectedTypes,
    required this.domainTypes,
    required this.isSuperseded,
    this.supersededBy,
    required this.isPending,
  });
}

class RawEnumMember {
  final String name;
  final String enumType;

  RawEnumMember({
    required this.name,
    required this.enumType,
  });
}

const dataTypes = [
  'Text',
  'Number',
  'Boolean',
  'Date',
  'DateTime',
  'Time',
  'URL',
  'Integer',
  'Float',
  'CssSelectorType',
  'PronounceableText',
  'XPathType',
];

String stripPrefix(String s) {
  for (final prefix in ['https://schema.org/', 'http://schema.org/', 'schema:']) {
    if (s.startsWith(prefix)) {
      return s.substring(prefix.length);
    }
  }
  return s;
}

String getType(Map<String, dynamic> entry) {
  final raw = entry['@type'];
  if (raw is String) return raw;
  if (raw is List && raw.isNotEmpty && raw.first is String) {
    return raw.first as String;
  }
  return '';
}

List<String> getIdList(Map<String, dynamic> entry, String key) {
  final val = entry[key];
  if (val is Map && val.containsKey('@id')) {
    return [stripPrefix(val['@id'] as String)];
  } else if (val is List) {
    final list = <String>[];
    for (final item in val) {
      if (item is Map && item.containsKey('@id')) {
        list.add(stripPrefix(item['@id'] as String));
      }
    }
    return list;
  }
  return [];
}

String getComment(Map<String, dynamic> entry) {
  final val = entry['rdfs:comment'];
  if (val is String) return val;
  if (val is Map && val.containsKey('@value')) {
    return val['@value'] as String;
  }
  return '';
}

bool isPartOf(Map<String, dynamic> entry, String domain) {
  final list = getIdList(entry, 'schema:isPartOf');
  return list.any((s) => s.contains(domain));
}

(bool, String?) getSuperseded(Map<String, dynamic> entry) {
  final val = entry['schema:supersededBy'];
  if (val is Map && val.containsKey('@id')) {
    return (true, stripPrefix(val['@id'] as String));
  }
  return (false, null);
}

bool isEnumeration(List<String> parents, String name) {
  if (name == 'Enumeration') return true;
  return parents.contains('Enumeration');
}

void main() {
  final jsonLdPath = '/tmp/schemaorg-rs/schema-data/schemaorg-all-https.jsonld';
  final versionPath = '/tmp/schemaorg-rs/schema-data/SCHEMA_VERSION';

  final version = File(versionPath).existsSync()
      ? File(versionPath).readAsStringSync().trim()
      : '30.0';

  final jsonStr = File(jsonLdPath).readAsStringSync();
  final Map<String, dynamic> doc = jsonDecode(jsonStr) as Map<String, dynamic>;
  final List<dynamic> graph = doc['@graph'] as List<dynamic>;

  final rawTypes = <String, RawType>{};
  final rawProps = <String, RawProperty>{};
  final enumTypeNames = <String>{};
  final rawEnumMembers = <RawEnumMember>[];

  // Phase 1: classify all entries
  for (final item in graph) {
    if (item is! Map<String, dynamic>) continue;
    final id = item['@id'] as String? ?? '';
    if (id.isEmpty) continue;
    final name = stripPrefix(id);
    if (name.isEmpty) continue;

    final entryType = getType(item);

    switch (entryType) {
      case 'rdfs:Class':
        final parents = getIdList(item, 'rdfs:subClassOf');
        final isEnum = isEnumeration(parents, name);
        final isPending = isPartOf(item, 'pending.schema.org');
        final isAttic = isPartOf(item, 'attic.schema.org');
        final comment = getComment(item);

        if (isEnum) {
          enumTypeNames.add(name);
        }

        if (dataTypes.contains(name)) {
          continue;
        }

        rawTypes[name] = RawType(
          name: name,
          parentNames: parents,
          comment: comment,
          isPending: isPending,
          isAttic: isAttic,
        );
        break;

      case 'rdf:Property':
        final domain = getIdList(item, 'schema:domainIncludes');
        final range = getIdList(item, 'schema:rangeIncludes');
        final (isSuperseded, supersededBy) = getSuperseded(item);
        final isPending = isPartOf(item, 'pending.schema.org');

        rawProps[name] = RawProperty(
          name: name,
          expectedTypes: range,
          domainTypes: domain,
          isSuperseded: isSuperseded,
          supersededBy: supersededBy,
          isPending: isPending,
        );
        break;

      default:
        final typeLocal = stripPrefix(entryType);
        if (typeLocal.isNotEmpty && typeLocal != 'rdfs:Class' && typeLocal != 'rdf:Property') {
          rawEnumMembers.add(RawEnumMember(name: name, enumType: typeLocal));
        }
        break;
    }
  }

  // Phase 2: assign properties to types based on domainIncludes
  for (final prop in rawProps.values) {
    for (final domainType in prop.domainTypes) {
      if (rawTypes.containsKey(domainType)) {
        rawTypes[domainType]!.ownProperties.add(prop.name);
      }
    }
  }

  // Phase 3: resolve inheritance
  final allPropertiesCache = <String, List<String>>{};

  List<String> collectAllProps(String typeName, Set<String> visited) {
    if (allPropertiesCache.containsKey(typeName)) {
      return allPropertiesCache[typeName]!;
    }
    if (!visited.add(typeName)) {
      return [];
    }
    final raw = rawTypes[typeName];
    if (raw == null) return [];

    final all = <String>{...raw.ownProperties};
    for (final parent in raw.parentNames) {
      all.addAll(collectAllProps(parent, visited));
    }
    final result = all.toList()..sort();
    allPropertiesCache[typeName] = result;
    return result;
  }

  for (final typeName in rawTypes.keys) {
    collectAllProps(typeName, <String>{});
  }

  // Phase 4: filter enum members to those whose enumType is known
  final validEnumMembers = rawEnumMembers
      .where((m) => enumTypeNames.contains(m.enumType) || rawTypes.containsKey(m.enumType))
      .toList();

  validEnumMembers.sort((a, b) => a.name.compareTo(b.name));

  final sortedTypeNames = rawTypes.keys.toList()..sort();
  final sortedPropNames = rawProps.keys.toList()..sort();

  // Generate Dart file
  final buf = StringBuffer();
  buf.writeln('// AUTO-GENERATED from schemaorg-all-https.jsonld v$version');
  buf.writeln('// Do not edit manually.');
  buf.writeln('// ignore_for_file: constant_identifier_names, unused_element');
  buf.writeln();
  buf.writeln("import 'types.dart';");
  buf.writeln();

  // Emit types
  for (final name in sortedTypeNames) {
    final raw = rawTypes[name]!;
    final parents = raw.parentNames.map((s) => "'${escapeStr(s)}'").join(', ');
    final ownList = raw.ownProperties.toList()..sort();
    final own = ownList.map((s) => "'${escapeStr(s)}'").join(', ');
    final allProps = (allPropertiesCache[name] ?? []).map((s) => "'${escapeStr(s)}'").join(', ');
    final comment = escapeStr(raw.comment);

    buf.writeln("const _type_${validVar(name)} = TypeDef(");
    buf.writeln("  name: '$name',");
    buf.writeln("  parentTypes: [$parents],");
    buf.writeln("  ownProperties: [$own],");
    buf.writeln("  allProperties: [$allProps],");
    buf.writeln("  comment: '$comment',");
    buf.writeln("  isPending: ${raw.isPending},");
    buf.writeln("  isAttic: ${raw.isAttic},");
    buf.writeln(");");
    buf.writeln();
  }

  // Emit properties
  for (final name in sortedPropNames) {
    final raw = rawProps[name]!;
    final expected = raw.expectedTypes.map((s) => "'${escapeStr(s)}'").join(', ');
    final domain = raw.domainTypes.map((s) => "'${escapeStr(s)}'").join(', ');
    final supersededBy = raw.supersededBy != null ? "'${escapeStr(raw.supersededBy!)}'" : 'null';

    buf.writeln("const _prop_${validVar(name)} = PropertyDef(");
    buf.writeln("  name: '$name',");
    buf.writeln("  expectedTypes: [$expected],");
    buf.writeln("  domainTypes: [$domain],");
    buf.writeln("  isSuperseded: ${raw.isSuperseded},");
    buf.writeln("  supersededBy: $supersededBy,");
    buf.writeln("  isPending: ${raw.isPending},");
    buf.writeln(");");
    buf.writeln();
  }

  // Emit enum members
  for (var i = 0; i < validEnumMembers.length; i++) {
    final member = validEnumMembers[i];
    buf.writeln("const _enum_${validVar(member.name)}_$i = EnumMemberDef(");
    buf.writeln("  name: '${escapeStr(member.name)}',");
    buf.writeln("  enumType: '${escapeStr(member.enumType)}',");
    buf.writeln(");");
    buf.writeln();
  }

  // Map of types
  buf.writeln("const Map<String, TypeDef> _typeMap = {");
  for (final name in sortedTypeNames) {
    buf.writeln("  '$name': _type_${validVar(name)},");
  }
  buf.writeln("};");
  buf.writeln();

  // Map of props
  buf.writeln("const Map<String, PropertyDef> _propMap = {");
  for (final name in sortedPropNames) {
    buf.writeln("  '$name': _prop_${validVar(name)},");
  }
  buf.writeln("};");
  buf.writeln();

  // Map of enums
  buf.writeln("const Map<String, EnumMemberDef> _enumMap = {");
  final seenEnumNames = <String>{};
  for (var i = 0; i < validEnumMembers.length; i++) {
    final member = validEnumMembers[i];
    if (seenEnumNames.add(member.name)) {
      buf.writeln("  '${escapeStr(member.name)}': _enum_${validVar(member.name)}_$i,");
    }
  }
  buf.writeln("};");
  buf.writeln();

  // Lookups
  buf.writeln("TypeDef? lookupType(String name) => _typeMap[name];");
  buf.writeln("PropertyDef? lookupProperty(String name) => _propMap[name];");
  buf.writeln("EnumMemberDef? lookupEnumMember(String name) => _enumMap[name];");
  buf.writeln("String schemaVersion() => '$version';");
  buf.writeln();

  buf.writeln("const List<String> allTypeNames = [");
  for (final name in sortedTypeNames) {
    buf.writeln("  '$name',");
  }
  buf.writeln("];");
  buf.writeln();

  buf.writeln("const List<String> allPropertyNames = [");
  for (final name in sortedPropNames) {
    buf.writeln("  '$name',");
  }
  buf.writeln("];");

  File('lib/src/vocabulary/generated.dart').writeAsStringSync(buf.toString());
  print('Vocabulary regenerated successfully!');
}

String validVar(String s) {
  return s.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
}

String escapeStr(String s) {
  return s
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\r')
      .replaceAll('\t', r'\t')
      .replaceAll(r'$', r'\$');
}
