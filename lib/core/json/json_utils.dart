/// Helpers for reading loosely typed JSON payloads.
///
/// Providers frequently return the same field as a string or as a number;
/// these helpers keep the parsing code readable and consistent.
library;

/// Reads [value] as a string, accepting numbers.
String? asString(Object? value) {
  if (value == null) return null;
  if (value is String) return value;
  if (value is num || value is bool) return value.toString();
  return null;
}

/// Reads [value] as an integer, accepting numeric strings.
int? asInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

/// Reads [value] as a double, accepting numeric strings.
double? asDouble(Object? value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

/// Reads [value] as a JSON list.
List<Object?>? asList(Object? value) {
  if (value is List) return value.cast<Object?>();
  return null;
}

/// Reads [value] as a JSON object.
Map<String, Object?>? asMap(Object? value) {
  if (value is Map) return value.cast<String, Object?>();
  return null;
}

/// Returns the first non-null value of [keys] inside [map].
Object? pick(Map<String, Object?>? map, List<String> keys) {
  if (map == null) return null;
  for (final key in keys) {
    final value = map[key];
    if (value != null) return value;
  }
  return null;
}
