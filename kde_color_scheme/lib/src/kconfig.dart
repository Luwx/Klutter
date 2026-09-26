/// Reads a KConfig INI file into groups of raw string entries, in file order.
///
/// Nested groups keep KConfig's `][` separator in their name, e.g.
/// `Colors:Header][Inactive`. Repeated groups are merged, as KConfig does.
Map<String, Map<String, String>> parseKConfigGroups(String content) {
  final groups = <String, Map<String, String>>{};
  Map<String, String>? current;

  for (var line in content.split('\n')) {
    line = line.trim();
    if (line.isEmpty || line.startsWith('#') || line.startsWith(';')) {
      continue;
    }

    if (line.startsWith('[') && line.endsWith(']')) {
      current = groups.putIfAbsent(
        line.substring(1, line.length - 1),
        () => {},
      );
    } else if (current != null) {
      final eq = line.indexOf('=');
      if (eq > 0) {
        current[line.substring(0, eq).trim()] = line.substring(eq + 1).trim();
      }
    }
  }
  return groups;
}
