import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/sac_legal_consent.dart';

const _terms = 'https://sacdia.com/terms';
const _privacy = 'https://sacdia.com/privacy';

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: Center(child: child)),
    );

/// Finds the [TextSpan] whose text is [text] (the localization key in tests,
/// since no translations are loaded).
TextSpan _span(WidgetTester tester, String text) {
  TextSpan? found;
  for (final widget in tester.widgetList<RichText>(find.byType(RichText))) {
    widget.text.visitChildren((span) {
      if (span is TextSpan && span.text == text) found = span;
      return true;
    });
  }
  expect(found, isNotNull, reason: 'span "$text" not found');
  return found!;
}

void main() {
  group('SacLegalConsentCheckbox', () {
    testWidgets('toggles through onChanged', (tester) async {
      bool? changed;
      await tester.pumpWidget(_host(SacLegalConsentCheckbox(
        value: false,
        onChanged: (v) => changed = v,
        termsUrl: _terms,
        privacyUrl: _privacy,
        onOpenDocument: (_) async => true,
      )));

      await tester.tap(find.byType(Checkbox));

      expect(changed, isTrue);
    });

    testWidgets('disabled checkbox does not notify', (tester) async {
      var calls = 0;
      await tester.pumpWidget(_host(SacLegalConsentCheckbox(
        value: false,
        enabled: false,
        onChanged: (_) => calls++,
        termsUrl: _terms,
        privacyUrl: _privacy,
        onOpenDocument: (_) async => true,
      )));

      await tester.tap(find.byType(Checkbox), warnIfMissed: false);

      expect(calls, 0);
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);
    });

    testWidgets('terms and privacy links open their own url', (tester) async {
      final opened = <Uri>[];
      await tester.pumpWidget(_host(SacLegalConsentCheckbox(
        value: false,
        onChanged: (_) {},
        termsUrl: _terms,
        privacyUrl: _privacy,
        onOpenDocument: (uri) async {
          opened.add(uri);
          return true;
        },
      )));

      (_span(tester, 'auth.legal.terms_link').recognizer
              as TapGestureRecognizer)
          .onTap!();
      (_span(tester, 'auth.legal.privacy_link').recognizer
              as TapGestureRecognizer)
          .onTap!();
      await tester.pump();

      expect(opened, [Uri.parse(_terms), Uri.parse(_privacy)]);
    });

    testWidgets('shows a snackbar when the document cannot be opened',
        (tester) async {
      await tester.pumpWidget(_host(SacLegalConsentCheckbox(
        value: false,
        onChanged: (_) {},
        termsUrl: _terms,
        privacyUrl: _privacy,
        onOpenDocument: (_) async => false,
      )));

      (_span(tester, 'auth.legal.terms_link').recognizer
              as TapGestureRecognizer)
          .onTap!();
      await tester.pump();
      await tester.pump();

      expect(find.text('auth.legal.open_failed'), findsOneWidget);
    });

    testWidgets('a throwing opener is treated as a failed open',
        (tester) async {
      await tester.pumpWidget(_host(SacLegalConsentCheckbox(
        value: false,
        onChanged: (_) {},
        termsUrl: _terms,
        privacyUrl: _privacy,
        onOpenDocument: (_) async => throw StateError('boom'),
      )));

      (_span(tester, 'auth.legal.privacy_link').recognizer
              as TapGestureRecognizer)
          .onTap!();
      await tester.pump();
      await tester.pump();

      expect(find.text('auth.legal.open_failed'), findsOneWidget);
    });

    testWidgets('tap target is at least 48dp and exposes a semantics label',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(SacLegalConsentCheckbox(
        value: false,
        onChanged: (_) {},
        termsUrl: _terms,
        privacyUrl: _privacy,
        onOpenDocument: (_) async => true,
      )));

      final size = tester.getSize(find.byType(Checkbox));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(find.bySemanticsLabel(RegExp('auth.legal.consent_semantics')),
          findsOneWidget);
      handle.dispose();
    });

    testWidgets('disposes recognizers without errors when removed',
        (tester) async {
      await tester.pumpWidget(_host(SacLegalConsentCheckbox(
        value: false,
        onChanged: (_) {},
        termsUrl: _terms,
        privacyUrl: _privacy,
        onOpenDocument: (_) async => true,
      )));

      await tester.pumpWidget(_host(const SizedBox.shrink()));

      expect(tester.takeException(), isNull);
    });
  });

  group('SacLegalNoticeText', () {
    testWidgets('renders prefix and both links and opens them', (tester) async {
      final opened = <Uri>[];
      await tester.pumpWidget(_host(SacLegalNoticeText(
        termsUrl: _terms,
        privacyUrl: _privacy,
        onOpenDocument: (uri) async {
          opened.add(uri);
          return true;
        },
      )));

      expect(_span(tester, 'auth.legal.login_notice_prefix'), isNotNull);
      (_span(tester, 'auth.legal.terms_link').recognizer
              as TapGestureRecognizer)
          .onTap!();
      (_span(tester, 'auth.legal.privacy_link').recognizer
              as TapGestureRecognizer)
          .onTap!();
      await tester.pump();

      expect(opened, [Uri.parse(_terms), Uri.parse(_privacy)]);
    });

    testWidgets('shows a snackbar when the document cannot be opened',
        (tester) async {
      await tester.pumpWidget(_host(SacLegalNoticeText(
        termsUrl: _terms,
        privacyUrl: _privacy,
        onOpenDocument: (_) async => false,
      )));

      (_span(tester, 'auth.legal.terms_link').recognizer
              as TapGestureRecognizer)
          .onTap!();
      await tester.pump();
      await tester.pump();

      expect(find.text('auth.legal.open_failed'), findsOneWidget);
    });
  });
}
