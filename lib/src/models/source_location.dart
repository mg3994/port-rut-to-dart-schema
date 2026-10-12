/// Location in the original HTML document.
class SourceLocation {
  /// 1-indexed line number.
  final int line;

  /// 1-indexed column number.
  final int column;

  /// 0-indexed byte offset from the start of the HTML document.
  final int byteOffset;

  const SourceLocation({
    required this.line,
    required this.column,
    required this.byteOffset,
  });

  Map<String, dynamic> toJson() => {
        'line': line,
        'column': column,
        'byte_offset': byteOffset,
      };

  factory SourceLocation.fromJson(Map<String, dynamic> json) {
    return SourceLocation(
      line: json['line'] as int,
      column: json['column'] as int,
      byteOffset: json['byte_offset'] as int,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SourceLocation &&
          runtimeType == other.runtimeType &&
          line == other.line &&
          column == other.column &&
          byteOffset == other.byteOffset;

  @override
  int get hashCode => line.hashCode ^ column.hashCode ^ byteOffset.hashCode;

  @override
  String toString() =>
      'SourceLocation(line: $line, column: $column, byteOffset: $byteOffset)';
}
