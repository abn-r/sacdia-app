import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';

void main() {
  test('default accent is the logo blue', () {
    expect(SacAccent.byId(null).id, 'brand.blue');
    expect(SacAccent.byId('missing').color, AppColors.loginBrandBlue);
    expect(SacAccent.logoBlue.color, const Color(0xFF0B84F0));
  });

  test('catalog includes coral, clubs and every class', () {
    final ids = SacAccent.catalog.map((accent) => accent.id).toSet();
    expect(
        ids,
        containsAll([
          'brand.coral',
          'club.aventureros',
          'club.conquistadores',
          'club.guias',
          'class.lambs',
          'class.friend',
          'class.master_guide',
          'class.advanced_guide',
          'class.instructor_guide',
        ]));
    expect(
      SacAccent.catalog
          .where((accent) => accent.family == AccentFamily.classLevel)
          .length,
      15,
    );
  });

  test('every derived accent has a dark shade that reads on its tint', () {
    double contrast(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      final hi = la > lb ? la : lb;
      final lo = la > lb ? lb : la;
      return (hi + 0.05) / (lo + 0.05);
    }

    // Counters and badges paint `dark` text on the `light` tint.
    for (final accent in SacAccent.catalog) {
      expect(
        contrast(accent.dark, accent.light),
        greaterThanOrEqualTo(4.5),
        reason: '${accent.id} dark text on its light tint',
      );
    }
  });

  test('light accents use dark ink on the button', () {
    final bees = SacAccent.byId('class.busy_bees');
    expect(bees.onColor, const Color(0xFF131316));
    expect(SacAccent.logoBlue.onColor, Colors.white);
  });
}
