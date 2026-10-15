import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/widgets/instructor_candidates_provider.dart';
import 'package:sacdia_app/core/widgets/instructor_picker.dart';
import 'package:sacdia_app/core/widgets/instructor_selection.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/providers/dio_provider.dart';

import '../../features/certificate_import/support/test_app.dart';
import '../../support/instructor_fakes.dart';

/// Opens the picker from a button; [picked] receives what the sheet returns.
Future<void> _open(
  WidgetTester tester,
  FakeInstructorSearch search, {
  List<InstructorSelection?>? picked,
}) async {
  phoneSurface(tester, height: 2400);
  await tester.pumpWidget(wrapTestApp(
    Builder(
      builder: (context) => Scaffold(
        body: ElevatedButton(
          onPressed: () async {
            final value = await InstructorPicker.show(context);
            picked?.add(value);
          },
          child: const Text('abrir'),
        ),
      ),
    ),
    overrides: [search.override],
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initTestLocalization);

  group('rules', () {
    test('a search needs 3 characters and 2 per word', () {
      expect(InstructorRules.isSearchable('An'), isFalse);
      expect(InstructorRules.isSearchable('Ana'), isTrue);
      expect(InstructorRules.isSearchable('Ana G'), isFalse);
      expect(InstructorRules.isSearchable('  Ana   Gó '), isTrue);
    });

    test('a typed name is 3 to 150 characters once trimmed', () {
      expect(InstructorRules.freeName('  Ana   Gó  '), 'Ana Gó');
      expect(InstructorRules.freeName('Al'), isNull);
      expect(InstructorRules.freeName('a' * 151), isNull);
    });

    test('candidates parse name and photo, and skip rows without an id', () {
      final person = InstructorSelection.tryParseCandidate({
        'user_id': 'u1',
        'display_name': ' Ana Pérez ',
        'photo_url': 'https://r2/x.jpg',
      });
      expect(
          person,
          const InstructorSelection.user(
              id: 'u1',
              displayName: 'Ana Pérez',
              photoUrl: 'https://r2/x.jpg'));
      expect(
          InstructorSelection.tryParseCandidate({'display_name': 'X'}), isNull);
      expect(
          InstructorSelection.tryParseCandidate(
              {'user_id': 'u1', 'display_name': 'Ana', 'photo_url': null}),
          const InstructorSelection.user(id: 'u1', displayName: 'Ana'));
    });
  });

  group('search', () {
    testWidgets('does not query below 3 letters and asks for more',
        (tester) async {
      final search = FakeInstructorSearch();
      await _open(tester, search);

      await _type(tester, 'An');

      expect(search.queries, isEmpty);
      expect(find.text('Escribe al menos 3 letras'), findsOneWidget);
      // Nothing to use as a name yet either.
      expect(find.textContaining('como nombre'), findsNothing);
    });

    testWidgets('does not query when a word has a single letter',
        (tester) async {
      final search = FakeInstructorSearch();
      await _open(tester, search);

      await _type(tester, 'Ana G');

      expect(search.queries, isEmpty);
      expect(find.text('Sigue escribiendo el nombre'), findsOneWidget);
      expect(find.text('Usar «Ana G» como nombre'), findsOneWidget);
    });

    testWidgets('debounces typing by 300 ms and sends one query',
        (tester) async {
      final search = FakeInstructorSearch();
      await _open(tester, search);

      await tester.enterText(find.byType(TextField), 'Ana');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextField), 'Ana Gó');
      await tester.pump(const Duration(milliseconds: 299));
      expect(search.queries, isEmpty);

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(search.queries, ['Ana Gó']);
    });

    testWidgets('lists people with their name and picks one', (tester) async {
      final picked = <InstructorSelection?>[];
      final search = FakeInstructorSearch();
      await _open(tester, search, picked: picked);

      await _type(tester, 'Ana');

      expect(find.text('Ana Gómez'), findsOneWidget);
      expect(find.text('Ana Góngora'), findsOneWidget);
      expect(find.text('Personas de tu Campo Local'), findsOneWidget);

      await tester.tap(find.text('Ana Góngora'));
      await tester.pumpAndSettle();
      expect(picked.single, anaGongora);
    });

    testWidgets('always offers the typed text as a free name', (tester) async {
      final picked = <InstructorSelection?>[];
      final search = FakeInstructorSearch();
      await _open(tester, search, picked: picked);

      await _type(tester, 'Ana');
      // Results are there and the free name is still the last row.
      expect(find.text('Ana Gómez'), findsOneWidget);
      expect(find.text('Usar «Ana» como nombre'), findsOneWidget);
      expect(
        find.text('Para instructores de otro Campo Local o que no están en '
            'SACDIA'),
        findsOneWidget,
      );

      await tester.tap(find.text('Usar «Ana» como nombre'));
      await tester.pumpAndSettle();
      expect(picked.single, const InstructorSelection.external('Ana'));
    });

    testWidgets('with nobody found, the free name is still the way out',
        (tester) async {
      final picked = <InstructorSelection?>[];
      await _open(tester, FakeInstructorSearch(), picked: picked);

      await _type(tester, 'Zacarías Quispe');

      expect(find.textContaining('No encontramos a nadie'), findsOneWidget);
      await tester.tap(find.text('Usar «Zacarías Quispe» como nombre'));
      await tester.pumpAndSettle();
      expect(
          picked.single, const InstructorSelection.external('Zacarías Quispe'));
    });

    testWidgets('shows the loader while the answer is pending', (tester) async {
      final pending = Completer<List<InstructorSelection>>();
      final search = FakeInstructorSearch((_) => pending.future);
      await _open(tester, search);

      await tester.enterText(find.byType(TextField), 'Ana');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(find.text('Ana Gómez'), findsNothing);
      expect(find.byType(SacLoading), findsOneWidget);
      expect(find.text('Usar «Ana» como nombre'), findsOneWidget);

      pending.complete([anaGomez]);
      await tester.pumpAndSettle();
      expect(find.text('Ana Gómez'), findsOneWidget);
    });

    testWidgets('cancels the request of the text that was replaced',
        (tester) async {
      final pending = Completer<List<InstructorSelection>>();
      final search = FakeInstructorSearch((q) {
        if (q == 'Ana') return pending.future;
        return Future.value([anaGongora]);
      });
      await _open(tester, search);

      await tester.enterText(find.byType(TextField), 'Ana');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      final first = search.tokens.single!;
      expect(first.isCancelled, isFalse);

      await tester.enterText(find.byType(TextField), 'Ana Gón');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(first.isCancelled, isTrue);
      expect(search.queries, ['Ana', 'Ana Gón']);
      expect(find.text('Ana Góngora'), findsOneWidget);
    });

    testWidgets('a rate limit (429) is explained kindly and can retry',
        (tester) async {
      var calls = 0;
      final search = FakeInstructorSearch((_) async {
        calls++;
        if (calls == 1) {
          throw const InstructorSearchException(
              InstructorSearchError.rateLimited);
        }
        return [anaGomez];
      });
      await _open(tester, search);

      await _type(tester, 'Ana');

      expect(find.textContaining('buscando muy rápido'), findsOneWidget);
      expect(find.textContaining('429'), findsNothing);
      // The way out does not depend on the search.
      expect(find.text('Usar «Ana» como nombre'), findsOneWidget);

      await tester.tap(find.widgetWithText(SacButton, 'Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Ana Gómez'), findsOneWidget);
    });

    testWidgets('a failed search says so, keeps the free name and retries',
        (tester) async {
      var fail = true;
      final search = FakeInstructorSearch((_) async {
        if (fail) {
          throw const InstructorSearchException(InstructorSearchError.offline);
        }
        return [anaGomez];
      });
      await _open(tester, search);

      await _type(tester, 'Ana');
      expect(
          find.text('No pudimos buscar. Revisa tu conexión'), findsOneWidget);
      expect(find.text('Usar «Ana» como nombre'), findsOneWidget);

      fail = false;
      await tester.tap(find.widgetWithText(SacButton, 'Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Ana Gómez'), findsOneWidget);
    });
  });

  group('accessibility', () {
    testWidgets('result rows and actions are at least 48 px tall',
        (tester) async {
      await _open(tester, FakeInstructorSearch());
      await _type(tester, 'Ana');

      for (final label in ['Ana Gómez', 'Usar «Ana» como nombre']) {
        final row = find.ancestor(
          of: find.text(label),
          matching: find.byType(ConstrainedBox),
        );
        final size = tester.getSize(row.first);
        expect(size.height, greaterThanOrEqualTo(48), reason: label);
      }
    });

    testWidgets('announces how many people were found', (tester) async {
      final announcements = <String>[];
      tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<dynamic>(
        SystemChannels.accessibility,
        (message) async {
          final data = (message as Map?)?['data'];
          if (data is Map && data['message'] is String) {
            announcements.add(data['message'] as String);
          }
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<dynamic>(
              SystemChannels.accessibility, null));
      await _open(tester, FakeInstructorSearch());

      await _type(tester, 'Ana');

      expect(announcements, contains('2 personas encontradas'));
    });
  });

  test('the real search sends q and parses name and photo', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    RequestOptions? seen;
    dio.httpClientAdapter = _StubAdapter((options) {
      seen = options;
      return {
        'status': 'success',
        'data': [
          {'user_id': 'u1', 'display_name': 'Ana Pérez', 'photo_url': null},
          {'oops': true},
        ],
      };
    });
    final container = ProviderContainer(
      overrides: [dioProvider.overrideWithValue(dio)],
    );
    addTearDown(container.dispose);

    final provider = instructorCandidatesProvider('Ana');
    container.listen(provider, (_, __) {});
    final people = await container.read(provider.future);

    expect(seen?.path, '/instructor-candidates');
    expect(seen?.queryParameters, {'q': 'Ana'});
    expect(people,
        [const InstructorSelection.user(id: 'u1', displayName: 'Ana Pérez')]);
  });

  test('the real search maps 429 to a rate limit', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    dio.httpClientAdapter = _StubAdapter((_) => {}, status: 429);
    final container = ProviderContainer(
      overrides: [dioProvider.overrideWithValue(dio)],
    );
    addTearDown(container.dispose);

    final provider = instructorCandidatesProvider('Ana');
    container.listen(provider, (_, __) {});
    await expectLater(
      container.read(provider.future),
      throwsA(isA<InstructorSearchException>()
          .having((e) => e.error, 'error', InstructorSearchError.rateLimited)),
    );
  });
}

/// Answers every request with [body] as JSON and the given [status].
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.body, {this.status = 200});

  final Object Function(RequestOptions options) body;
  final int status;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(body(options)),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
