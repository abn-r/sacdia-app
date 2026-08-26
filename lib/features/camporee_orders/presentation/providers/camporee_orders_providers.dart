import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../providers/dio_provider.dart';
import '../../../auth/domain/utils/authorization_utils.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../camporees/domain/entities/camporee_member.dart';
import '../../../camporees/presentation/providers/camporees_providers.dart';
import '../../../payment_orders/domain/entities/payment_obligation.dart';
import '../../data/datasources/camporee_orders_remote_data_source.dart';
import '../../data/repositories/camporee_orders_repository_impl.dart';
import '../../domain/entities/camporee_order.dart';
import '../../domain/entities/camporee_order_offering.dart';
import '../../domain/repositories/camporee_orders_repository.dart';

// ── Infrastructure ──────────────────────────────────────────────────────────

final camporeeOrdersRemoteDataSourceProvider =
    Provider<CamporeeOrdersRemoteDataSource>((ref) {
  return CamporeeOrdersRemoteDataSourceImpl(
    dio: ref.read(dioProvider),
    baseUrl: ref.read(apiBaseUrlProvider),
  );
});

final camporeeOrdersRepositoryProvider =
    Provider<CamporeeOrdersRepository>((ref) {
  return CamporeeOrdersRepositoryImpl(
    remoteDataSource: ref.read(camporeeOrdersRemoteDataSourceProvider),
  );
});

// ── Scope ───────────────────────────────────────────────────────────────────

class CamporeeOrdersScope extends Equatable {
  final int camporeeId;
  final CamporeeKind type;

  const CamporeeOrdersScope({
    required this.camporeeId,
    this.type = CamporeeKind.local,
  });

  factory CamporeeOrdersScope.fromQuery(int camporeeId, String? type) {
    return CamporeeOrdersScope(
      camporeeId: camporeeId,
      type: camporeeKindFromQuery(type),
    );
  }

  String get typeQuery => type == CamporeeKind.union ? 'union' : 'local';

  @override
  List<Object?> get props => [camporeeId, type];
}

CamporeeKind camporeeKindFromQuery(String? type) {
  return type == 'union' ? CamporeeKind.union : CamporeeKind.local;
}

/// Ventana de emisión derivada de settings (fail-closed si está apagado).
enum CamporeeOrdersWindow { disabled, notOpen, closed, open }

CamporeeOrdersWindow evaluateCamporeeOrdersWindow(
  CamporeeOrderSettings settings, {
  DateTime? now,
  DateTime? eventEnd,
}) {
  if (!settings.ordersEnabled) return CamporeeOrdersWindow.disabled;
  final t = now ?? DateTime.now();
  if (settings.ordersOpensAt != null && t.isBefore(settings.ordersOpensAt!)) {
    return CamporeeOrdersWindow.notOpen;
  }
  if (settings.ordersDeadline != null && t.isAfter(settings.ordersDeadline!)) {
    return CamporeeOrdersWindow.closed;
  }
  if (eventEnd != null) {
    final endDay = DateTime(eventEnd.year, eventEnd.month, eventEnd.day);
    final today = DateTime(t.year, t.month, t.day);
    if (today.isAfter(endDay)) return CamporeeOrdersWindow.closed;
  }
  return CamporeeOrdersWindow.open;
}

/// CTA en detalle: pedidos activos + sección inscrita. Fail-closed en error.
enum CamporeeOrdersCtaState { hidden, closed, notOpen, open }

CamporeeOrdersCtaState resolveCamporeeOrdersCtaState({
  required bool sectionEnrolled,
  CamporeeOrderSettings? settings,
  int? offeringsErrorCode,
  DateTime? now,
  DateTime? eventEnd,
}) {
  if (!sectionEnrolled) return CamporeeOrdersCtaState.hidden;
  if (settings != null) {
    switch (evaluateCamporeeOrdersWindow(
      settings,
      now: now,
      eventEnd: eventEnd,
    )) {
      case CamporeeOrdersWindow.disabled:
        return CamporeeOrdersCtaState.hidden;
      case CamporeeOrdersWindow.notOpen:
        return CamporeeOrdersCtaState.notOpen;
      case CamporeeOrdersWindow.closed:
        return CamporeeOrdersCtaState.closed;
      case CamporeeOrdersWindow.open:
        return CamporeeOrdersCtaState.open;
    }
  }
  if (offeringsErrorCode == 422) return CamporeeOrdersCtaState.closed;
  return CamporeeOrdersCtaState.hidden;
}

// ── Permission helpers ───────────────────────────────────────────────────────

final canDistributeCamporeeOrdersProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  final authState = await ref.watch(authNotifierProvider.future);
  if (authState == null) return false;
  return hasAnyPermission(authState, const {'camporee-orders:distribute'});
});

final canCreateCamporeeOrdersProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  final authState = await ref.watch(authNotifierProvider.future);
  if (authState == null) return false;
  return hasAnyPermission(authState, const {'camporee-orders:create'});
});

// ── Queries ──────────────────────────────────────────────────────────────────

final camporeeOrderOfferingsProvider = FutureProvider.autoDispose
    .family<CamporeeOrderOfferingsCatalog, CamporeeOrdersScope>(
        (ref, scope) async {
  final repository = ref.read(camporeeOrdersRepositoryProvider);
  final result = await repository.getOfferings(
    camporeeId: scope.camporeeId,
    camporeeType: scope.type,
  );
  return result.fold(
    (failure) => throw failure,
    (catalog) => catalog,
  );
});

final camporeeOrdersListProvider = FutureProvider.autoDispose
    .family<List<CamporeeOrder>, CamporeeOrdersScope>((ref, scope) async {
  final repository = ref.read(camporeeOrdersRepositoryProvider);
  final result = await repository.listOrders(
    camporeeId: scope.type == CamporeeKind.local ? scope.camporeeId : null,
    unionCamporeeId: scope.type == CamporeeKind.union ? scope.camporeeId : null,
  );
  return result.fold(
    (failure) => throw failure,
    (orders) => orders,
  );
});

final camporeeOrderDetailProvider = FutureProvider.autoDispose
    .family<CamporeeOrder, String>((ref, orderId) async {
  final repository = ref.read(camporeeOrdersRepositoryProvider);
  final result = await repository.getOrder(orderId);
  return result.fold(
    (failure) => throw failure,
    (order) => order,
  );
});

/// Roster del camporee: inscritos activos `registered|approved`. Nunca club.
final camporeeOrderRosterProvider = FutureProvider.autoDispose
    .family<List<CamporeeMember>, int>((ref, camporeeId) async {
  final repository = ref.read(camporeesRepositoryProvider);
  const statuses = ['registered', 'approved'];
  final members = <CamporeeMember>[];
  final seen = <int>{};

  for (final status in statuses) {
    var page = 1;
    var hasNextPage = true;
    while (hasNextPage) {
      final result = await repository.getCamporeeMembers(
        camporeeId,
        page: page,
        limit: 100,
        status: status,
      );
      final paginated = result.fold(
        (failure) => throw failure,
        (value) => value,
      );
      for (final member in paginated.data) {
        if (member.active && seen.add(member.camporeeMemberId)) {
          members.add(member);
        }
      }
      hasNextPage = paginated.meta.hasNextPage;
      page += 1;
    }
  }

  members.sort(
    (a, b) => (a.userName ?? a.userEmail ?? '')
        .toLowerCase()
        .compareTo((b.userName ?? b.userEmail ?? '').toLowerCase()),
  );
  return members;
});

final pendingPaymentObligationsProvider =
    FutureProvider.autoDispose<List<PaymentObligation>>((ref) async {
  final repository = ref.read(camporeeOrdersRepositoryProvider);
  final result = await repository.listPendingObligations();
  return result.fold(
    (failure) => throw failure,
    (items) => items,
  );
});

// ── Draft cart (in-memory) ───────────────────────────────────────────────────

class CamporeeOrderDraftLine extends Equatable {
  final int camporeeMemberId;
  final String memberName;
  final String offeringId;
  final String productTitle;
  final String? optionId;
  final String? optionLabel;
  final int qty;
  final int unitPriceCentavos;

  const CamporeeOrderDraftLine({
    required this.camporeeMemberId,
    required this.memberName,
    required this.offeringId,
    required this.productTitle,
    required this.qty,
    required this.unitPriceCentavos,
    this.optionId,
    this.optionLabel,
  });

  int get lineTotalCentavos => unitPriceCentavos * qty;

  CamporeeOrderLineInput toInput() => CamporeeOrderLineInput(
        camporeeMemberId: camporeeMemberId,
        offeringId: offeringId,
        optionId: optionId,
        qty: qty,
      );

  CamporeeOrderDraftLine copyWith({int? qty}) {
    return CamporeeOrderDraftLine(
      camporeeMemberId: camporeeMemberId,
      memberName: memberName,
      offeringId: offeringId,
      productTitle: productTitle,
      optionId: optionId,
      optionLabel: optionLabel,
      qty: qty ?? this.qty,
      unitPriceCentavos: unitPriceCentavos,
    );
  }

  @override
  List<Object?> get props =>
      [camporeeMemberId, offeringId, optionId, qty, unitPriceCentavos];
}

class CamporeeOrderDraftState {
  final List<CamporeeOrderDraftLine> lines;
  final bool isSubmitting;
  final String? errorMessage;
  final CamporeeOrder? issuedOrder;

  const CamporeeOrderDraftState({
    this.lines = const [],
    this.isSubmitting = false,
    this.errorMessage,
    this.issuedOrder,
  });

  int get totalCentavos =>
      lines.fold(0, (sum, line) => sum + line.lineTotalCentavos);

  CamporeeOrderDraftState copyWith({
    List<CamporeeOrderDraftLine>? lines,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
    CamporeeOrder? issuedOrder,
    bool clearIssued = false,
  }) {
    return CamporeeOrderDraftState(
      lines: lines ?? this.lines,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      issuedOrder: clearIssued ? null : (issuedOrder ?? this.issuedOrder),
    );
  }
}

List<CamporeeOrderSummaryItem> deriveDraftSummary(
  List<CamporeeOrderDraftLine> lines,
) {
  final grouped = <String, CamporeeOrderSummaryItem>{};
  for (final line in lines) {
    final key = '${line.productTitle}|${line.optionLabel ?? ''}';
    final current = grouped[key];
    if (current == null) {
      grouped[key] = CamporeeOrderSummaryItem(
        productTitleSnapshot: line.productTitle,
        optionLabelSnapshot: line.optionLabel,
        qty: line.qty,
        subtotalCentavos: line.lineTotalCentavos,
      );
    } else {
      grouped[key] = CamporeeOrderSummaryItem(
        productTitleSnapshot: current.productTitleSnapshot,
        optionLabelSnapshot: current.optionLabelSnapshot,
        qty: current.qty + line.qty,
        subtotalCentavos: current.subtotalCentavos + line.lineTotalCentavos,
      );
    }
  }
  return grouped.values.toList();
}

class CamporeeOrderDraftNotifier extends AutoDisposeFamilyNotifier<
    CamporeeOrderDraftState, CamporeeOrdersScope> {
  @override
  CamporeeOrderDraftState build(CamporeeOrdersScope arg) =>
      const CamporeeOrderDraftState();

  void upsertLine(CamporeeOrderDraftLine line) {
    final next = [...state.lines];
    final index = next.indexWhere(
      (item) =>
          item.camporeeMemberId == line.camporeeMemberId &&
          item.offeringId == line.offeringId &&
          item.optionId == line.optionId,
    );
    if (line.qty <= 0) {
      if (index >= 0) next.removeAt(index);
    } else if (index >= 0) {
      next[index] = line;
    } else {
      next.add(line);
    }
    state = state.copyWith(lines: next, clearError: true, clearIssued: true);
  }

  void clear() {
    state = const CamporeeOrderDraftState();
  }

  Future<CamporeeOrder?> submit() async {
    if (state.lines.isEmpty || state.isSubmitting) return null;
    final keepAliveLink = ref.keepAlive();
    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      final result =
          await ref.read(camporeeOrdersRepositoryProvider).createOrder(
                camporeeId: arg.camporeeId,
                camporeeType: arg.type,
                lines: state.lines.map((line) => line.toInput()).toList(),
                idempotencyKey:
                    '${arg.camporeeId}-${DateTime.now().microsecondsSinceEpoch}',
              );
      return result.fold(
        (failure) {
          state = state.copyWith(
            isSubmitting: false,
            errorMessage: failure.message,
          );
          return null;
        },
        (order) {
          state = CamporeeOrderDraftState(issuedOrder: order);
          ref.invalidate(camporeeOrdersListProvider(arg));
          ref.invalidate(pendingPaymentObligationsProvider);
          return order;
        },
      );
    } finally {
      keepAliveLink.close();
    }
  }
}

final camporeeOrderDraftProvider = NotifierProvider.autoDispose.family<
    CamporeeOrderDraftNotifier, CamporeeOrderDraftState, CamporeeOrdersScope>(
  CamporeeOrderDraftNotifier.new,
);

// ── Order actions (pdf / proof / cancel / deliver) ──────────────────────────

class CamporeeOrderActionsState {
  final bool isWorking;
  final String? errorMessage;

  const CamporeeOrderActionsState({this.isWorking = false, this.errorMessage});
}

class CamporeeOrderActionsNotifier
    extends AutoDisposeNotifier<CamporeeOrderActionsState> {
  @override
  CamporeeOrderActionsState build() => const CamporeeOrderActionsState();

  Future<bool> uploadProof({
    required String orderId,
    required String filePath,
    required String fileName,
    required String mimeType,
  }) {
    return _run(
      () => ref.read(camporeeOrdersRepositoryProvider).uploadProof(
            orderId: orderId,
            filePath: filePath,
            fileName: fileName,
            mimeType: mimeType,
          ),
      invalidateOrderId: orderId,
    );
  }

  Future<bool> cancelOrder(String orderId) {
    return _run(
      () => ref.read(camporeeOrdersRepositoryProvider).cancelOrder(orderId),
      invalidateOrderId: orderId,
    );
  }

  Future<bool> deliverLineToMember({
    required String orderId,
    required String lineId,
  }) {
    return _run(
      () => ref.read(camporeeOrdersRepositoryProvider).deliverLineToMember(
            orderId: orderId,
            lineId: lineId,
          ),
      invalidateOrderId: orderId,
    );
  }

  Future<String?> downloadPdf(String orderId) async {
    if (state.isWorking) return null;
    state = const CamporeeOrderActionsState(isWorking: true);
    final result = await ref
        .read(camporeeOrdersRepositoryProvider)
        .downloadOrderPdf(orderId);
    return result.fold(
      (failure) {
        state = CamporeeOrderActionsState(errorMessage: failure.message);
        return null;
      },
      (path) {
        state = const CamporeeOrderActionsState();
        return path;
      },
    );
  }

  Future<bool> _run(
    Future<dynamic> Function() action, {
    required String invalidateOrderId,
  }) async {
    if (state.isWorking) return false;
    state = const CamporeeOrderActionsState(isWorking: true);

    final result = await action();
    return result.fold(
      (failure) {
        state = CamporeeOrderActionsState(errorMessage: failure.message);
        return false;
      },
      (_) {
        state = const CamporeeOrderActionsState();
        ref.invalidate(camporeeOrderDetailProvider(invalidateOrderId));
        ref.invalidate(camporeeOrdersListProvider);
        ref.invalidate(pendingPaymentObligationsProvider);
        return true;
      },
    );
  }
}

final camporeeOrderActionsProvider = NotifierProvider.autoDispose<
    CamporeeOrderActionsNotifier, CamporeeOrderActionsState>(
  CamporeeOrderActionsNotifier.new,
);

String camporeeOrdersErrorMessage(Object error) {
  if (error is Failure) return error.message;
  final text = error.toString();
  if (text.startsWith('Exception: ')) {
    return text.substring('Exception: '.length);
  }
  return text;
}
