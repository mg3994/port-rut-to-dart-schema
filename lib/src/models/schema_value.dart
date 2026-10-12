import 'schema_node.dart';

/// A value within a structured data node.
sealed class SchemaValue {
  const SchemaValue();
}

/// Plain text content.
final class SchemaValueText extends SchemaValue {
  final String value;
  const SchemaValueText(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SchemaValueText &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// A URL value.
final class SchemaValueUrl extends SchemaValue {
  final String value;
  const SchemaValueUrl(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SchemaValueUrl &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// A nested structured data node.
final class SchemaValueNode extends SchemaValue {
  final SchemaNode node;
  const SchemaValueNode(this.node);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SchemaValueNode &&
          runtimeType == other.runtimeType &&
          node == other.node;

  @override
  int get hashCode => node.hashCode;

  @override
  String toString() => '[${node.types.join(", ")} node]';
}

/// A boolean value.
final class SchemaValueBoolean extends SchemaValue {
  final bool value;
  const SchemaValueBoolean(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SchemaValueBoolean &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value.toString();
}

/// A numeric value.
final class SchemaValueNumber extends SchemaValue {
  final num value;
  const SchemaValueNumber(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SchemaValueNumber &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value.toString();
}

/// A raw datetime string.
final class SchemaValueDateTime extends SchemaValue {
  final String value;
  const SchemaValueDateTime(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SchemaValueDateTime &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
