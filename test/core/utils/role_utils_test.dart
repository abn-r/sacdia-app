import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/utils/role_utils.dart';

import '../../features/coordinator/coordinator_test_harness.dart';

/// Pumps a localized app in [locale] and returns what [read] computes from a
/// context that already has the real translations loaded.
Future<T> _inLocale<T>(
  WidgetTester tester,
  Locale locale,
  T Function() read,
) async {
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: [locale],
      path: 'assets/translations',
      assetLoader: const FileAssetLoader(),
      fallbackLocale: locale,
      startLocale: locale,
      child: Builder(
        builder: (context) {
          return MaterialApp(
            locale: context.locale,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            home: const SizedBox.shrink(),
          );
        },
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  // Read once the translations are loaded.
  return read();
}

void main() {
  setUpAll(initCoordinatorTestLocalization);

  group('RoleUtils.translate (es)', () {
    testWidgets('uses the feminine form for a woman', (tester) async {
      final labels = await _inLocale(tester, const Locale('es'), () {
        return {
          'secretary': RoleUtils.translate('secretary', gender: 'F'),
          'director': RoleUtils.translate('director', gender: 'F'),
          'deputy': RoleUtils.translate('deputy-director', gender: 'F'),
          'treasurer': RoleUtils.translate('treasurer', gender: 'F'),
          'both': RoleUtils.translate('secretary-treasurer', gender: 'F'),
          'counselor': RoleUtils.translate('counselor', gender: 'F'),
          'instructor': RoleUtils.translate('instructor', gender: 'F'),
        };
      });

      expect(labels, {
        'secretary': 'Secretaria',
        'director': 'Directora',
        'deputy': 'Subdirectora',
        'treasurer': 'Tesorera',
        'both': 'Secretaria-Tesorera',
        'counselor': 'Consejera',
        'instructor': 'Instructora',
      });
    });

    testWidgets('accepts the API spellings of a feminine gender',
        (tester) async {
      final labels = await _inLocale(tester, const Locale('es'), () {
        return [
          RoleUtils.translate('secretary', gender: 'F'),
          RoleUtils.translate('secretary', gender: 'f'),
          RoleUtils.translate('secretary', gender: 'Femenino'),
          RoleUtils.translate('secretary', gender: ' femenino '),
        ];
      });

      expect(labels, everyElement('Secretaria'));
    });

    testWidgets('uses the masculine form for a man', (tester) async {
      final labels = await _inLocale(tester, const Locale('es'), () {
        return [
          RoleUtils.translate('secretary', gender: 'M'),
          RoleUtils.translate('secretary', gender: 'Masculino'),
          RoleUtils.translate('secretary-treasurer', gender: 'M'),
        ];
      });

      expect(labels, ['Secretario', 'Secretario', 'Secretario-Tesorero']);
    });

    testWidgets('falls back to the masculine form with unknown gender',
        (tester) async {
      final labels = await _inLocale(tester, const Locale('es'), () {
        return [
          RoleUtils.translate('secretary'),
          RoleUtils.translate('secretary', gender: null),
          RoleUtils.translate('secretary', gender: ''),
          RoleUtils.translate('secretary', gender: 'X'),
        ];
      });

      expect(labels, everyElement('Secretario'));
    });

    testWidgets('keeps invariant roles and unknown roles', (tester) async {
      final labels = await _inLocale(tester, const Locale('es'), () {
        return [
          RoleUtils.translate('member', gender: 'F'),
          RoleUtils.translate('custom_role', gender: 'F'),
          RoleUtils.translate(null, gender: 'F'),
          RoleUtils.translate('', gender: 'F'),
        ];
      });

      expect(labels, ['Miembro', 'Custom role', '', '']);
    });

    testWidgets('translateList applies the gender to every role',
        (tester) async {
      final label = await _inLocale(tester, const Locale('es'), () {
        return RoleUtils.translateList(
          ['director', 'treasurer'],
          gender: 'F',
        );
      });

      expect(label, 'Directora, Tesorera');
    });
  });

  group('RoleUtils.translate (other locales)', () {
    testWidgets('fr', (tester) async {
      final labels = await _inLocale(tester, const Locale('fr'), () {
        return [
          RoleUtils.translate('director', gender: 'F'),
          RoleUtils.translate('director', gender: 'M'),
          RoleUtils.translate('secretary', gender: 'F'),
          RoleUtils.translate('treasurer', gender: 'F'),
        ];
      });

      expect(labels, ['Directrice', 'Directeur', 'Secrétaire', 'Trésorière']);
    });

    testWidgets('pt-BR', (tester) async {
      final labels = await _inLocale(tester, const Locale('pt', 'BR'), () {
        return [
          RoleUtils.translate('director', gender: 'F'),
          RoleUtils.translate('secretary', gender: 'F'),
          RoleUtils.translate('secretary', gender: 'M'),
          RoleUtils.translate('treasurer', gender: 'F'),
        ];
      });

      expect(labels, ['Diretora', 'Secretária', 'Secretário', 'Tesoureira']);
    });

    testWidgets('en does not change with gender', (tester) async {
      final labels = await _inLocale(tester, const Locale('en'), () {
        return [
          RoleUtils.translate('secretary', gender: 'F'),
          RoleUtils.translate('secretary', gender: 'M'),
          RoleUtils.translate('secretary-treasurer', gender: 'F'),
        ];
      });

      expect(labels, ['Secretary', 'Secretary', 'Secretary-Treasurer']);
    });
  });
}
