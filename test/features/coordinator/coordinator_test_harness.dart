/// Shared harness for coordinator view tests: loads the real Spanish
/// translations (so assertions read like the UI and a missing key fails the
/// test) and enables reduced motion so counters/cards resolve immediately.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/providers/riverpod_aliases.dart';
import 'package:sacdia_app/features/coordinator/domain/entities/evidence_review_item.dart';
import 'package:sacdia_app/features/coordinator/presentation/providers/coordinator_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> initCoordinatorTestLocalization() async {
  SharedPreferences.setMockInitialValues({});
  await EasyLocalization.ensureInitialized();
}

class FileAssetLoader extends AssetLoader {
  const FileAssetLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async {
    final file = File('$path/${locale.toLanguageTag()}.json');
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }
}

/// Wraps [child] (usually a `ProviderScope`-free app) in EasyLocalization.
Widget localized(Widget Function(BuildContext context) buildApp) {
  return EasyLocalization(
    supportedLocales: const [Locale('es')],
    path: 'assets/translations',
    assetLoader: const FileAssetLoader(),
    fallbackLocale: const Locale('es'),
    startLocale: const Locale('es'),
    child: Builder(builder: buildApp),
  );
}

Widget reducedMotion(BuildContext context, Widget? child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    );

/// A [MaterialApp.router] with Spanish localization and reduced motion.
Widget localizedRouterApp(BuildContext context, GoRouter router) {
  return MaterialApp.router(
    routerConfig: router,
    locale: context.locale,
    localizationsDelegates: context.localizationDelegates,
    supportedLocales: context.supportedLocales,
    builder: reducedMotion,
  );
}

/// A plain localized [MaterialApp] with reduced motion.
Widget localizedApp(BuildContext context, Widget home) {
  return MaterialApp(
    locale: context.locale,
    localizationsDelegates: context.localizationDelegates,
    supportedLocales: context.supportedLocales,
    builder: reducedMotion,
    home: home,
  );
}

void useTallSurface(WidgetTester tester, {Size size = const Size(800, 2600)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

// ── Pending evidence queue ──────────────────────────────────────────────────

/// Returns page [page] of the queue for [type] (null = every type).
typedef PendingPageLoader = FutureOr<EvidenceReviewPage> Function(
  EvidenceReviewType? type,
  int page,
);

/// [PendingEvidenceNotifier] with the real paging logic and a fake source.
class FakePendingEvidenceNotifier extends PendingEvidenceNotifier {
  FakePendingEvidenceNotifier(this.loader);

  final PendingPageLoader loader;

  @override
  Future<EvidenceReviewPage> fetchPage(
    int page, {
    CancelToken? cancelToken,
  }) async =>
      loader(arg, page);
}

Override pendingEvidenceOverride(PendingPageLoader loader) =>
    pendingEvidenceProvider.overrideWith(
      () => FakePendingEvidenceNotifier(loader),
    );

/// A queue that fits in one page: the server total is [items.length] unless
/// [total] says otherwise.
EvidenceReviewPage singlePage(List<EvidenceReviewItem> items, {int? total}) =>
    EvidenceReviewPage(
      items: items,
      total: total ?? items.length,
      page: 1,
      limit: kPendingEvidencePageSize,
    );

/// Page [page] of [all], [kPendingEvidencePageSize] items per page.
EvidenceReviewPage pageOf(List<EvidenceReviewItem> all, int page) {
  final start = (page - 1) * kPendingEvidencePageSize;
  return EvidenceReviewPage(
    items: all.skip(start).take(kPendingEvidencePageSize).toList(),
    total: all.length,
    page: page,
    limit: kPendingEvidencePageSize,
  );
}
