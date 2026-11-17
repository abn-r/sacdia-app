import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/dio_provider.dart';
import '../../../auth/domain/utils/authorization_utils.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../members/presentation/providers/members_providers.dart';
import '../../data/datasources/insurance_remote_data_source.dart';
import '../../data/repositories/insurance_repository_impl.dart';
import '../../domain/entities/insurance_overview.dart';
import '../../domain/entities/member_insurance.dart';
import '../../domain/repositories/insurance_repository.dart';

// ── Infrastructure ──────────────────────────────────────────────────────────

final insuranceRemoteDataSourceProvider =
    Provider<InsuranceRemoteDataSource>((ref) {
  return InsuranceRemoteDataSourceImpl(
    dio: ref.read(dioProvider),
    baseUrl: ref.read(apiBaseUrlProvider),
  );
});

final insuranceRepositoryProvider = Provider<InsuranceRepository>((ref) {
  return InsuranceRepositoryImpl(
    remoteDataSource: ref.read(insuranceRemoteDataSourceProvider),
  );
});

// ── Permissions ─────────────────────────────────────────────────────────────

/// What the user may do in the insurance module. Read-only users see the
/// list but no footer, checkboxes or reassign action.
class InsuranceAccess {
  const InsuranceAccess({
    this.canIssue = false,
    this.canReassign = false,
    this.canViewOrders = false,
  });

  /// Issue orders, upload receipts, cancel (`field-payment-orders:create`).
  final bool canIssue;

  /// Pass a free insurance on (`insurance:create`).
  final bool canReassign;

  /// Open the list of orders (`field-payment-orders:read`).
  final bool canViewOrders;

  static const readOnly = InsuranceAccess();
}

final insuranceAccessProvider =
    FutureProvider.autoDispose<InsuranceAccess>((ref) async {
  final auth = await ref.watch(authNotifierProvider.future);
  if (auth == null) return InsuranceAccess.readOnly;
  final canIssue =
      hasAnyPermission(auth, const {'field-payment-orders:create'});
  return InsuranceAccess(
    canIssue: canIssue,
    canReassign: hasAnyPermission(auth, const {'insurance:create'}),
    canViewOrders:
        canIssue || hasAnyPermission(auth, const {'field-payment-orders:read'}),
  );
});

// ── Overview ────────────────────────────────────────────────────────────────

/// Year, cost, counts and the people of the active section. `null` without a
/// club context.
final insuranceOverviewProvider =
    FutureProvider.autoDispose<InsuranceOverview?>((ref) async {
  final ctx = await ref.watch(clubContextProvider.future);
  if (ctx == null) return null;
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  final result = await ref
      .read(insuranceRepositoryProvider)
      .getOverview(sectionId: ctx.sectionId);
  return result.fold((failure) => throw failure, (overview) => overview);
});

/// Coverages left free by someone who left the club.
final freeCoveragesProvider =
    FutureProvider.autoDispose<List<FreeCoverage>>((ref) async {
  final ctx = await ref.watch(clubContextProvider.future);
  if (ctx == null) return const [];
  final result = await ref
      .read(insuranceRepositoryProvider)
      .getFreeCoverages(sectionId: ctx.sectionId);
  return result.fold((failure) => throw failure, (items) => items);
});

// ── Legacy list (camporee registration without payment orders) ──────────────

final membersInsuranceProvider =
    FutureProvider.autoDispose<List<MemberInsurance>>((ref) async {
  final ctx = await ref.watch(clubContextProvider.future);
  if (ctx == null) return [];

  final result =
      await ref.read(insuranceRepositoryProvider).getMembersInsurance(
            clubId: ctx.clubId,
            sectionId: ctx.sectionId,
          );
  return result.fold((failure) => throw failure, (list) => list);
});
