import 'schema_node.dart';

/// A value within a structured data node.
sealed class SchemaValue {
  const SchemaValue();

  /// Converts this [SchemaValue] into a JSON-compatible Dart primitive/map value.
  dynamic toJson() {
    return switch (this) {
      SchemaValueText(:final value) => value,
      SchemaValueUrl(:final value) => value,
      SchemaValueNode(:final node) => node.toJson(),
      SchemaValueBoolean(:final value) => value,
      SchemaValueNumber(:final value) => value,
      SchemaValueDateTime(:final value) => value,
    };
  }

  /// Deserializes a JSON value into a [SchemaValue].
  static SchemaValue fromJson(dynamic value) {
    if (value is bool) return SchemaValueBoolean(value);
    if (value is num) return SchemaValueNumber(value);
    if (value is Map<String, dynamic>) {
      return SchemaValueNode(SchemaNode.fromJson(value));
    }
    if (value is Map) {
      return SchemaValueNode(
        SchemaNode.fromJson(Map<String, dynamic>.from(value)),
      );
    }
    if (value is String) {
      if (value.startsWith('http://') || value.startsWith('https://')) {
        return SchemaValueUrl(value);
      }
      return SchemaValueText(value);
    }
    return SchemaValueText(value.toString());
  }
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
