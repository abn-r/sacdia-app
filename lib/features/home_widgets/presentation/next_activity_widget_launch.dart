import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../../../core/config/route_names.dart';
import '../../../core/config/router.dart';
import '../../../core/utils/app_logger.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../domain/next_activity_widget_link.dart';

/// Escucha toques del widget y abre el detalle cuando ya hay sesión.
void Function() bindNextActivityWidgetLaunches(WidgetRef ref) {
  ProviderSubscription<dynamic>? authWait;
  var disposed = false;

  void open(Uri? uri) {
    if (disposed) return;
    final activityId = activityIdFromWidgetUri(uri);
    if (activityId == null) return;

    final auth = ref.read(authNotifierProvider);
    if (!auth.isLoading) {
      if (auth.valueOrNull == null) return;
      ref.read(routerProvider).go(RouteNames.activityDetailPath(activityId));
      return;
    }

    authWait?.close();
    var settled = false;
    late final ProviderSubscription<dynamic> subscription;
    subscription = ref.listenManual(
      authNotifierProvider,
      (_, next) {
        if (next.isLoading) return;
        settled = true;
        subscription.close();
        if (identical(authWait, subscription)) authWait = null;
        if (disposed || next.valueOrNull == null) return;
        ref.read(routerProvider).go(RouteNames.activityDetailPath(activityId));
      },
      fireImmediately: true,
    );
    if (!settled) authWait = subscription;
  }

  final subscription = HomeWidget.widgetClicked.listen(
    open,
    onError: (Object error) {
      AppLogger.w(
        'No se pudo leer el toque del widget',
        tag: 'NextActivityWidget',
        error: error,
      );
    },
  );

  HomeWidget.initiallyLaunchedFromHomeWidget().then(
    open,
    onError: (Object error) {
      AppLogger.w(
        'No se pudo leer el arranque desde el widget',
        tag: 'NextActivityWidget',
        error: error,
      );
    },
  );

  return () {
    disposed = true;
    subscription.cancel();
    authWait?.close();
  };
}
