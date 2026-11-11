/// Vertical rhythm of the home screen.
///
/// Cards cast a soft shadow that eats about 3 pt of the gap, so card to card
/// uses 20 to read like the other gaps (about 17 pt on screen).
abstract final class HomeSpacing {
  /// Between the club line and the first card. The club line already keeps a
  /// 44 pt tap target, so 16 reads the same as the gap between cards.
  static const double header = 16;

  /// Below every card or banner. Self-hiding widgets keep it themselves, so a
  /// hidden one leaves no gap.
  static const double card = 20;

  /// Between a card and the next section title («Acceso rápido»...). The
  /// title's line height adds its own air.
  static const double section = 16;
}
