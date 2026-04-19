String toDisplayText(String value) {
  final text = value.trim();
  if (text.isEmpty) {
    return '';
  }

  if (text.contains('@')) {
    return text.toLowerCase();
  }

  final lower = text.toLowerCase();
  const acronyms = {'cc', 'ce', 'nit', 'ppt', 'pas', 'na'};

  if (acronyms.contains(lower)) {
    return lower.toUpperCase();
  }

  return '${lower[0].toUpperCase()}${lower.substring(1)}';
}

String toDisplayUserName(String value) {
  return value.trim().toUpperCase();
}
