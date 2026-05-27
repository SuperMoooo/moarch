/// Utility helpers for naming and casing conversions.
class StringUtils {
  StringUtils._();

  /// Returns the generated toSnakeCase template.
  static String toSnakeCase(String input) {
    return input
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (m) => '${m[1]}_${m[2]}',
        )
        .replaceAll(RegExp(r'[\s\-]+'), '_')
        .toLowerCase();
  }

  /// Returns the generated toPascalCase template.
  static String toPascalCase(String input) {
    final snake = toSnakeCase(input);
    return snake
        .split('_')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join();
  }

  /// Returns the generated toCamelCase template.
  static String toCamelCase(String input) {
    final pascal = toPascalCase(input);
    if (pascal.isEmpty) return pascal;
    return '${pascal[0].toLowerCase()}${pascal.substring(1)}';
  }
}
