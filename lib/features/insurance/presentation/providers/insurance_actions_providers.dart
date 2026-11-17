import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/errors/user_error_message.dart';
import '../../../../core/providers/keep_alive_during.dart';
import '../../../payment_orders/domain/entities/payment_order.dart';
import '../../../payment_orders/presentation/providers/payment_orders_providers.dart';
import '../../domain/entities/insurance_conflict.dart';
import 'insurance_providers.dart';

/// A business error already carries a translated message (the data source
/// maps the code); anything else gets the generic text, never a raw one.
String _safeFailureMessage(Failure failure, {required String fallbackKey}) {
  if (failure is ServerFailure &&
      failure.errorCode != null &&
      failure.message.trim().isNotEmpty) {
    return failure.message;
  }
  return userErrorMessage(failure, fallbackKey: fallbackKey);
}

// ── Issue an order ──────────────────────────────────────────────────────────

class InsuranceIssueState {
  const InsuranceIssueState({
    this.isSubmitting = false,
    this.errorMessage,
    this.conflicts = const [],
    this.issuedOrder,
  });

  final bool isSubmitting;

  /// Safe message of the last failure that was not a conflict.
  final String? errorMessage;

  /// People the server refused: the screen explains and drops them.
  final List<InsuranceConflict> conflicts;
  final PaymentOrder? issuedOrder;
}

/// Issues the insurance order of the selected people.
///
/// The same selection retried after a network failure reuses its
/// `Idempotency-Key`, so a lost response never turns into two orders. A new
/// selection (or a conflict) gets a new key.
class InsuranceIssueNotifier extends Notifier<InsuranceIssueState> {
  String? _key;
  String? _keyFor;

  @override
  InsuranceIssueState build() => const InsuranceIssueState();

  String _keyForSelection(int cycleConfigId, List<String> ids) {
    final fingerprint = '$cycleConfigId:${([...ids]..sort()).join(',')}';
    if (_key == null || _keyFor != fingerprint) {
      // The backend stores it in a uuid column: it must be a UUID.
      _key = _uuidV4(Random.secure());
      _keyFor = fingerprint;
    }
    return _key!;
  }

  void clearConflicts() {
    state = InsuranceIssueState(
      isSubmitting: state.isSubmitting,
      errorMessage: state.errorMessage,
    );
  }

  Future<PaymentOrder?> submit({
    required int cycleConfigId,
    required List<String> beneficiaryUserIds,
  }) async {
    if (beneficiaryUserIds.isEmpty || state.isSubmitting) return null;
    state = const InsuranceIssueState(isSubmitting: true);
    final key = _keyForSelection(cycleConfigId, beneficiaryUserIds);

    return ref.keepAliveDuring(() async {
      final result =
          await ref.read(paymentOrdersRepositoryProvider).createInsuranceOrder(
                cycleConfigId: cycleConfigId,
                beneficiaryUserIds: beneficiaryUserIds,
                idempotencyKey: key,
              );
      return result.fold(
        (failure) {
          if (failure is DuplicateBeneficiariesFailure) {
            _key = null;
            state = InsuranceIssueState(conflicts: failure.conflicts);
            // The list on screen is stale: refresh it behind the sheet.
            ref.invalidate(insuranceOverviewProvider);
            return null;
          }
          state = InsuranceIssueState(errorMessage: _message(failure));
          return null;
        },
        (order) {
          _key = null;
          state = InsuranceIssueState(issuedOrder: order);
          ref.invalidate(paymentOrdersListProvider);
          ref.invalidate(insuranceOverviewProvider);
          return order;
        },
      );
    });
  }

  String _message(Failure failure) => _safeFailureMessage(
        failure,
        fallbackKey: 'insurance.issue.error_generic',
      );
}

final insuranceIssueNotifierProvider =
    NotifierProvider.autoDispose<InsuranceIssueNotifier, InsuranceIssueState>(
  InsuranceIssueNotifier.new,
);

// ── Reassign ────────────────────────────────────────────────────────────────

class InsuranceReassignState {
  const InsuranceReassignState({
    this.isSubmitting = false,
    this.errorMessage,
    this.done = false,
  });

  final bool isSubmitting;
  final String? errorMessage;
  final bool done;
}

/// Passes a free insurance to someone without one. The server runs it at
/// once (no approval) and records who did it.
class InsuranceReassignNotifier extends Notifier<InsuranceReassignState> {
  @override
  InsuranceReassignState build() => const InsuranceReassignState();

  Future<bool> submit({
    required int assignmentId,
    required String toUserId,
  }) async {
    if (state.isSubmitting) return false;
    state = const InsuranceReassignState(isSubmitting: true);

    return ref.keepAliveDuring(() async {
      final result =
          await ref.read(paymentOrdersRepositoryProvider).createReassignment(
                insuranceAssignmentId: assignmentId,
                toUserId: toUserId,
              );
      return result.fold(
        (failure) {
          state = InsuranceReassignState(
            errorMessage: _safeFailureMessage(
              failure,
              fallbackKey: 'insurance.reassign.error_generic',
            ),
          );
          // Someone may have been insured meanwhile: refresh the choices.
          ref
            ..invalidate(insuranceOverviewProvider)
            ..invalidate(freeCoveragesProvider);
          return false;
        },
        (_) {
          state = const InsuranceReassignState(done: true);
          ref
            ..invalidate(insuranceOverviewProvider)
            ..invalidate(freeCoveragesProvider);
          return true;
        },
      );
    });
  }
}

final insuranceReassignNotifierProvider = NotifierProvider.autoDispose<
    InsuranceReassignNotifier, InsuranceReassignState>(
  InsuranceReassignNotifier.new,
);

/// RFC 4122 version 4 UUID (no extra dependency).
String _uuidV4(Random rnd) {
  final b = List<int>.generate(16, (_) => rnd.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}
