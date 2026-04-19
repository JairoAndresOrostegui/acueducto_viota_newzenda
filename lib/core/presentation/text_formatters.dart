String toDisplayText(String value) {
  final text = value.trim();
  if (text.isEmpty) {
    return '';
  }

  if (text.contains('@')) {
    return text.toLowerCase();
  }

  return text
      .split(RegExp(r'\s+'))
      .map((word) {
        if (word.isEmpty) {
          return word;
        }

        final lower = word.toLowerCase();
        return '${lower[0].toUpperCase()}${lower.substring(1)}';
      })
      .join(' ');
}
