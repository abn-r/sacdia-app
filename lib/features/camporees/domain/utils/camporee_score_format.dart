/// ASCII decimal without grouping — same rule as admin `formatTabularNumber`.
String formatCamporeeScoreNumber(num value) {
  if (value % 1 == 0) return value.round().toString();
  var text = value.toStringAsFixed(2);
  if (text.contains('.')) {
    text = text.replaceFirst(RegExp(r'0+$'), '');
    if (text.endsWith('.')) {
      text = text.substring(0, text.length - 1);
    }
  }
  return text;
}
