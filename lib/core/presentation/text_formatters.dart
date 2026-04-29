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

  const labels = {
    'al_dia': 'Al día',
    'en_mora': 'En mora',
  };
  final knownLabel = labels[lower];
  if (knownLabel != null) {
    return knownLabel;
  }

  final readable = lower.replaceAll('_', ' ');
  return '${readable[0].toUpperCase()}${readable.substring(1)}';
}

String toDisplayUserName(String value) {
  return value.trim().toUpperCase();
}
