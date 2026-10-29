import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/auth/session_mode.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/usecases/cancellation_token.dart';
import 'package:sacdia_app/features/notifications/domain/entities/notification_item.dart';
import 'package:sacdia_app/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:sacdia_app/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:sacdia_app/features/notifications/presentation/views/notifications_inbox_view.dart';

import '../../../members/members_test_support.dart';

class _EmptyRepository implements NotificationsRepository {
  @override
  Future<
          Either<Failure,
              ({List<NotificationItem> items, int total, int totalPages})>>
      getHistory({
    int page = 1,
    int limit = 20,
    RequestCancelToken? cancelToken,
  }) async =>
          right((items: <NotificationItem>[], total: 0, totalPages: 1));

  @override
  Future<Either<Failure, int>> getUnreadCount() async => right(0);

  @override
  Future<Either<Failure, void>> markAsRead(String deliveryId) async =>
      right(null);

  @override
  Future<Either<Failure, int>> markAllAsRead() async => right(0);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initLocalization);

  Future<void> open(WidgetTester tester, {required SessionMode mode}) async {
    await pumpMembersApp(
      tester,
      overrides: [
        notificationsRepositoryProvider.overrideWithValue(_EmptyRepository()),
        sessionModeProvider.overrideWith((ref) => mode),
      ],
      home: const NotificationsInboxView(),
    );
    await tester.pumpAndSettle();
  }

  const bellTooltip = 'Notificaciones';

  testWidgets('a normal account sees the bell action in the app bar',
      (tester) async {
    await open(tester, mode: SessionMode.account);

    expect(find.byTooltip(bellTooltip), findsOneWidget);
    expect(find.byTooltip('Actualizar'), findsOneWidget);
  });

  testWidgets(
      'a linked device does not get a bell: it has no notification '
      'preferences to open', (tester) async {
    await open(tester, mode: SessionMode.device);

    expect(find.byTooltip(bellTooltip), findsNothing);
    expect(find.byTooltip('Actualizar'), findsOneWidget,
        reason: 'the rest of the actions stay');
  });

  testWidgets('an account keeps the "Notificaciones" title', (tester) async {
    await open(tester, mode: SessionMode.account);

    expect(find.text('Notificaciones'), findsOneWidget);
    expect(find.text('Avisos'), findsNothing);
  });

  testWidgets('a linked device titles the screen "Avisos", like its tab',
      (tester) async {
    await open(tester, mode: SessionMode.device);

    expect(find.text('Avisos'), findsOneWidget);
    expect(find.text('Notificaciones'), findsNothing);
  });
}
