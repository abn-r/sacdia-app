import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/dio_provider.dart';
import '../../../auth/domain/utils/authorization_utils.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/payment_orders_remote_data_source.dart';
import '../../data/repositories/payment_orders_repository_impl.dart';
import '../../domain/entities/payment_order.dart';
import '../../domain/repositories/payment_orders_repository.dart';

// ── Infrastructure ──────────────────────────────────────────────────────────

final paymentOrdersRemoteDataSourceProvider =
    Provider<PaymentOrdersRemoteDataSource>((ref) {
  return PaymentOrdersRemoteDataSourceImpl(
    dio: ref.read(dioProvider),
    baseUrl: ref.read(apiBaseUrlProvider),
  );
});

final paymentOrdersRepositoryProvider = Provider<PaymentOrdersRepository>((ref) {
  return PaymentOrdersRepositoryImpl(
    remoteDataSource: ref.read(paymentOrdersRemoteDataSourceProvider),
  );
});

// ── Permission helpers ───────────────────────────────────────────────────────

/// True si el usuario puede emitir órdenes de pago (secretaría/tesorería/dirección).
final canIssuePaymentOrdersProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  final authState = await ref.watch(authNotifierProvider.future);
  if (authState == null) return false;
  return hasAnyPermission(authState, const {'field-payment-orders:create'});
});

// ── Context (flag + ciclos) ──────────────────────────────────────────────────

/// Disponibilidad del flujo de órdenes para la sección activa.
final paymentOrdersContextProvider =
    FutureProvider.autoDispose<PaymentOrdersContext?>((ref) async {
  final canIssue = await ref.watch(canIssuePaymentOrdersProvider.future);
  final authState = await ref.watch(authNotifierProvider.future);
  final canRead = authState != null &&
      hasAnyPermission(authState, const {'field-payment-orders:read'});
  if (!canIssue && !canRead) return null;

  final repository = ref.read(paymentOrdersRepositoryProvider);
  final result = await repository.getContext();
  return result.fold(
    // Sin sección activa o sin acceso: el flujo simplemente no se ofrece.
    (failure) => null,
    (context) => context,
  );
});

// ── Orders list ──────────────────────────────────────────────────────────────

/// Filtro de la lista de órdenes.
class PaymentOrdersFilter {
  final PaymentOrderPurpose? purpose;
  final int? camporeeId;

  const PaymentOrdersFilter({this.purpose, this.camporeeId});

  @override
  bool operator ==(Object other) =>
      other is PaymentOrdersFilter &&
      other.purpose == purpose &&
      other.camporeeId == camporeeId;

  @override
  int get hashCode => Object.hash(purpose, camporeeId);
}

final paymentOrdersListProvider = FutureProvider.autoDispose
    .family<List<PaymentOrder>, PaymentOrdersFilter>((ref, filter) async {
  final repository = ref.read(paymentOrdersRepositoryProvider);
  final result = await repository.listOrders(
    purpose: filter.purpose,
    camporeeId: filter.camporeeId,
  );
  return result.fold(
    (failure) => throw Exception(failure.message),
    (orders) => orders,
  );
});

// ── Order detail ─────────────────────────────────────────────────────────────

final paymentOrderDetailProvider = FutureProvider.autoDispose
    .family<PaymentOrder, String>((ref, orderId) async {
  final repository = ref.read(paymentOrdersRepositoryProvider);
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  final result = await repository.getOrder(orderId);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (order) => order,
  );
});

// ── Issue order (multi-select + submit) ─────────────────────────────────────

/// Estado del flujo de emisión de una orden.
class IssueOrderState {
  final Set<String> selectedUserIds;
  final bool isSubmitting;
  final String? errorMessage;
  final PaymentOrder? issuedOrder;

  const IssueOrderState({
    this.selectedUserIds = const {},
    this.isSubmitting = false,
    this.errorMessage,
    this.issuedOrder,
  });

  IssueOrderState copyWith({
    Set<String>? selectedUserIds,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
    PaymentOrder? issuedOrder,
  }) {
    return IssueOrderState(
      selectedUserIds: selectedUserIds ?? this.selectedUserIds,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      issuedOrder: issuedOrder ?? this.issuedOrder,
    );
  }
}

/// Notifier del flujo de emisión (selección de beneficiarios y submit).
class IssueOrderNotifier extends AutoDisposeNotifier<IssueOrderState> {
  @override
  IssueOrderState build() => const IssueOrderState();

  void toggle(String userId) {
    final selected = {...state.selectedUserIds};
    if (!selected.remove(userId)) selected.add(userId);
    state = state.copyWith(selectedUserIds: selected, clearError: true);
  }

  void clearSelection() =>
      state = state.copyWith(selectedUserIds: const {}, clearError: true);

  Future<PaymentOrder?> submitInsurance({required int cycleConfigId}) {
    return _submit(
      (repo) => repo.createInsuranceOrder(
        cycleConfigId: cycleConfigId,
        beneficiaryUserIds: state.selectedUserIds.toList(),
      ),
    );
  }

  Future<PaymentOrder?> submitCamporee({
    required int camporeeId,
    String camporeeType = 'local',
  }) {
    return _submit(
      (repo) => repo.createCamporeeOrder(
        camporeeId: camporeeId,
        beneficiaryUserIds: state.selectedUserIds.toList(),
        camporeeType: camporeeType,
      ),
    );
  }

  Future<PaymentOrder?> _submit(
    Future<dynamic> Function(PaymentOrdersRepository repo) action,
  ) async {
    if (state.selectedUserIds.isEmpty || state.isSubmitting) return null;
    state = state.copyWith(isSubmitting: true, clearError: true);

    final result = await action(ref.read(paymentOrdersRepositoryProvider));
    return result.fold(
      (failure) {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: failure.message as String?,
        );
        return null;
      },
      (order) {
        state = state.copyWith(
          isSubmitting: false,
          issuedOrder: order as PaymentOrder,
        );
        ref.invalidate(paymentOrdersListProvider);
        return order;
      },
    );
  }
}

final issueOrderNotifierProvider =
    NotifierProvider.autoDispose<IssueOrderNotifier, IssueOrderState>(
  IssueOrderNotifier.new,
);

// ── Order actions (proof upload / cancel / pdf) ─────────────────────────────

/// Estado de las acciones sobre una orden (subida de comprobante, cancelar…).
class OrderActionsState {
  final bool isWorking;
  final String? errorMessage;

  const OrderActionsState({this.isWorking = false, this.errorMessage});
}

/// Acciones del detalle de orden. Invalida el detalle y la lista al mutar.
class OrderActionsNotifier extends AutoDisposeNotifier<OrderActionsState> {
  @override
  OrderActionsState build() => const OrderActionsState();

  Future<bool> uploadProof({
    required String orderId,
    required String filePath,
    required String fileName,
    required String mimeType,
  }) async {
    return _run(() async {
      final result = await ref.read(paymentOrdersRepositoryProvider).uploadProof(
            orderId: orderId,
            filePath: filePath,
            fileName: fileName,
            mimeType: mimeType,
          );
      return result;
    }, invalidateOrderId: orderId);
  }

  Future<bool> cancelOrder(String orderId) {
    return _run(
      () => ref.read(paymentOrdersRepositoryProvider).cancelOrder(orderId),
      invalidateOrderId: orderId,
    );
  }

  Future<String?> downloadPdf(String orderId) async {
    state = const OrderActionsState(isWorking: true);
    final result = await ref
        .read(paymentOrdersRepositoryProvider)
        .downloadOrderPdf(orderId);
    return result.fold(
      (failure) {
        state = OrderActionsState(errorMessage: failure.message);
        return null;
      },
      (path) {
        state = const OrderActionsState();
        return path;
      },
    );
  }

  Future<bool> _run(
    Future<dynamic> Function() action, {
    required String invalidateOrderId,
  }) async {
    if (state.isWorking) return false;
    state = const OrderActionsState(isWorking: true);

    final result = await action();
    return result.fold(
      (failure) {
        state = OrderActionsState(errorMessage: failure.message as String?);
        return false;
      },
      (_) {
        state = const OrderActionsState();
        ref.invalidate(paymentOrderDetailProvider(invalidateOrderId));
        ref.invalidate(paymentOrdersListProvider);
        return true;
      },
    );
  }
}

final orderActionsNotifierProvider =
    NotifierProvider.autoDispose<OrderActionsNotifier, OrderActionsState>(
  OrderActionsNotifier.new,
);
