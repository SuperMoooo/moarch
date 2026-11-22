/// Reads one value out of parsed YAML by its key path, with types.
library;

/// Returns the value at [path] — keys separated by dots, such as
/// `'flavors.prod.android.applicationId'` — inside [document], a map from
/// `loadYaml`.
///
/// `loadYaml` returns untyped maps, so chaining `doc['a']['b']` is a call on
/// `dynamic` that `avoid_dynamic_calls` rejects. Walking the path here checks
/// each level is a map and fails with the key that is missing, instead of a
/// `NoSuchMethodError` on null.
Object? yamlAt(Object? document, String path) {
  Object? node = document;
  for (final key in path.split('.')) {
    if (node is! Map) {
      throw StateError('"$key" in "$path": the parent is not a map ($node)');
    }
    if (!node.containsKey(key)) {
      throw StateError('"$key" in "$path" is missing');
    }
    node = node[key];
  }
  return node;
}
