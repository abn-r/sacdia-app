import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../providers/dio_provider.dart';
import '../../../auth/domain/utils/authorization_utils.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../miembros/presentation/providers/miembros_providers.dart';
import '../../data/datasources/seguros_remote_data_source.dart';
import '../../data/repositories/seguros_repository_impl.dart';
import '../../domain/entities/member_insurance.dart';
import '../../domain/repositories/seguros_repository.dart';
import '../../domain/usecases/create_insurance.dart';
import '../../domain/usecases/get_members_insurance.dart';
import '../../domain/usecases/update_insurance.dart';

// ── Infrastructure ──────────────────────────────────────────────────────────────

final segurosRemoteDataSourceProvider =
    Provider<SegurosRemoteDataSource>((ref) {
  return SegurosRemoteDataSourceImpl(
    dio: ref.read(dioProvider),
    baseUrl: ref.read(apiBaseUrlProvider),
  );
});

final segurosRepositoryProvider = Provider<SegurosRepository>((ref) {
  return SegurosRepositoryImpl(
    remoteDataSource: ref.read(segurosRemoteDataSourceProvider),
    networkInfo: ref.read(networkInfoProvider),
  );
});

// ── Use cases ───────────────────────────────────────────────────────────────────

final getMembersInsuranceUseCaseProvider = Provider<GetMembersInsurance>((ref) {
  return GetMembersInsurance(ref.read(segurosRepositoryProvider));
});

final createInsuranceUseCaseProvider = Provider<CreateInsurance>((ref) {
  return CreateInsurance(ref.read(segurosRepositoryProvider));
});

final updateInsuranceUseCaseProvider = Provider<UpdateInsurance>((ref) {
  return UpdateInsurance(ref.read(segurosRepositoryProvider));
});

// ── Permission helper ───────────────────────────────────────────────────────────

/// Roles autorizados para gestionar seguros del club.
const _segurosEditorRoles = {
  'director',
  'subdirector',
  'treasurer',
  'tesorero',
};

/// Devuelve true si el usuario puede crear/editar seguros.
final canManageSegurosProvider = FutureProvider.autoDispose<bool>((ref) async {
  final authState = await ref.watch(authNotifierProvider.future);
  if (authState == null) return false;

  return canByPermissionOrLegacyRole(
    authState,
    requiredPermissions: const {
      'club_roles:assign',
    },
    legacyRoles: _segurosEditorRoles,
  );
});

// ── Members insurance list ──────────────────────────────────────────────────────

final membersInsuranceProvider =
    FutureProvider.autoDispose<List<MemberInsurance>>((ref) async {
  final ctx = await ref.watch(clubContextProvider.future);
  if (ctx == null) return [];

  final useCase = ref.read(getMembersInsuranceUseCaseProvider);
  final result = await useCase(GetMembersInsuranceParams(
    clubId: ctx.clubId,
    instanceType: ctx.instanceType,
    instanceId: ctx.instanceId,
  ));

  return result.fold(
    (failure) => throw Exception(failure.message),
    (list) => list,
  );
});

// ── Filter & search state ───────────────────────────────────────────────────────

enum InsuranceStatusFilter { todos, asegurado, vencido, sinSeguro }

extension InsuranceStatusFilterLabel on InsuranceStatusFilter {
  String get label {
    switch (this) {
      case InsuranceStatusFilter.todos:
        return 'Todos';
      case InsuranceStatusFilter.asegurado:
        return 'Asegurado';
      case InsuranceStatusFilter.vencido:
        return 'Vencido';
      case InsuranceStatusFilter.sinSeguro:
        return 'Sin seguro';
    }
  }
}

enum InsuranceSortOrder { nameAsc, nameDesc, expiryAsc, expiryDesc }

extension InsuranceSortOrderLabel on InsuranceSortOrder {
  String get label {
    switch (this) {
      case InsuranceSortOrder.nameAsc:
        return 'Nombre A-Z';
      case InsuranceSortOrder.nameDesc:
        return 'Nombre Z-A';
      case InsuranceSortOrder.expiryAsc:
        return 'Vencimiento pronto';
      case InsuranceSortOrder.expiryDesc:
        return 'Vencimiento lejano';
    }
  }
}

/// Estado de los filtros de la pantalla de seguros.
class SegurosFilters {
  final String searchQuery;
  final InsuranceStatusFilter statusFilter;
  final InsuranceSortOrder sortOrder;

  const SegurosFilters({
    this.searchQuery = '',
    this.statusFilter = InsuranceStatusFilter.todos,
    this.sortOrder = InsuranceSortOrder.nameAsc,
  });

  SegurosFilters copyWith({
    String? searchQuery,
    InsuranceStatusFilter? statusFilter,
    InsuranceSortOrder? sortOrder,
  }) {
    return SegurosFilters(
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: statusFilter ?? this.statusFilter,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  bool get hasActiveFilters =>
      searchQuery.isNotEmpty || statusFilter != InsuranceStatusFilter.todos;

  List<MemberInsurance> applyTo(List<MemberInsurance> items) {
    var result = items.where((mi) {
      // Búsqueda por nombre
      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        if (!mi.memberName.toLowerCase().contains(query)) return false;
      }
      // Filtro por estado
      switch (statusFilter) {
        case InsuranceStatusFilter.todos:
          break;
        case InsuranceStatusFilter.asegurado:
          if (mi.status != InsuranceStatus.asegurado) return false;
        case InsuranceStatusFilter.vencido:
          if (mi.status != InsuranceStatus.vencido) return false;
        case InsuranceStatusFilter.sinSeguro:
          if (mi.status != InsuranceStatus.sinSeguro) return false;
      }
      return true;
    }).toList();

    // Ordenamiento
    switch (sortOrder) {
      case InsuranceSortOrder.nameAsc:
        result.sort((a, b) => a.memberName.compareTo(b.memberName));
      case InsuranceSortOrder.nameDesc:
        result.sort((a, b) => b.memberName.compareTo(a.memberName));
      case InsuranceSortOrder.expiryAsc:
        result.sort((a, b) {
          // Sin fecha al final
          if (a.endDate == null && b.endDate == null) return 0;
          if (a.endDate == null) return 1;
          if (b.endDate == null) return -1;
          return a.endDate!.compareTo(b.endDate!);
        });
      case InsuranceSortOrder.expiryDesc:
        result.sort((a, b) {
          if (a.endDate == null && b.endDate == null) return 0;
          if (a.endDate == null) return 1;
          if (b.endDate == null) return -1;
          return b.endDate!.compareTo(a.endDate!);
        });
    }

    return result;
  }
}

final segurosFiltersProvider =
    StateProvider.autoDispose<SegurosFilters>((ref) => const SegurosFilters());

final filteredMembersInsuranceProvider =
    Provider.autoDispose<AsyncValue<List<MemberInsurance>>>((ref) {
  final itemsAsync = ref.watch(membersInsuranceProvider);
  final filters = ref.watch(segurosFiltersProvider);
  return itemsAsync.whenData((items) => filters.applyTo(items));
});

// ── Summary stats ───────────────────────────────────────────────────────────────

class SegurosSummary {
  final int total;
  final int asegurados;
  final int vencidos;
  final int sinSeguro;

  const SegurosSummary({
    required this.total,
    required this.asegurados,
    required this.vencidos,
    required this.sinSeguro,
  });

  double get coveragePercent => total == 0 ? 0 : (asegurados / total * 100);
}

final segurosSummaryProvider = Provider.autoDispose<SegurosSummary?>((ref) {
  final itemsAsync = ref.watch(membersInsuranceProvider);
  return itemsAsync.valueOrNull?.let((items) {
    return SegurosSummary(
      total: items.length,
      asegurados:
          items.where((i) => i.status == InsuranceStatus.asegurado).length,
      vencidos: items.where((i) => i.status == InsuranceStatus.vencido).length,
      sinSeguro:
          items.where((i) => i.status == InsuranceStatus.sinSeguro).length,
    );
  });
});

extension _Nullable<T> on T? {
  R? let<R>(R Function(T) f) => this == null ? null : f(this as T);
}

// ── Insurance form notifier ─────────────────────────────────────────────────────

/// Estado del formulario de registro/edición de seguro.
class InsuranceFormState {
  final bool isLoading;
  final String? errorMessage;
  final bool success;
  final XFile? selectedFile;

  const InsuranceFormState({
    this.isLoading = false,
    this.errorMessage,
    this.success = false,
    this.selectedFile,
  });

  InsuranceFormState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    bool? success,
    XFile? selectedFile,
    bool clearFile = false,
  }) {
    return InsuranceFormState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      success: success ?? this.success,
      selectedFile: clearFile ? null : (selectedFile ?? this.selectedFile),
    );
  }
}

/// Notifier para el formulario de registro/edición de seguro.
class InsuranceFormNotifier extends StateNotifier<InsuranceFormState> {
  final CreateInsurance _create;
  final UpdateInsurance _update;
  final Ref _ref;

  InsuranceFormNotifier({
    required CreateInsurance create,
    required UpdateInsurance update,
    required Ref ref,
  })  : _create = create,
        _update = update,
        _ref = ref,
        super(const InsuranceFormState());

  void setFile(XFile? file) {
    if (file == null) {
      state = state.copyWith(clearFile: true, clearError: true);
    } else {
      state = state.copyWith(selectedFile: file, clearError: true);
    }
  }

  Future<bool> save({
    required String memberId,
    required InsuranceType insuranceType,
    required DateTime startDate,
    required DateTime endDate,
    String? policyNumber,
    String? providerName,
    double? coverageAmount,
    int? existingInsuranceId,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, success: false);

    final file = state.selectedFile;
    final String? mimeType = file != null ? _mimeFromPath(file.path) : null;

    if (existingInsuranceId != null) {
      // Actualizar
      final result = await _update(UpdateInsuranceParams(
        insuranceId: existingInsuranceId,
        insuranceType: insuranceType,
        startDate: startDate,
        endDate: endDate,
        policyNumber: policyNumber,
        providerName: providerName,
        coverageAmount: coverageAmount,
        evidenceFilePath: file?.path,
        evidenceFileName: file?.name,
        evidenceMimeType: mimeType,
      ));

      return result.fold(
        (failure) {
          state =
              state.copyWith(isLoading: false, errorMessage: failure.message);
          return false;
        },
        (_) {
          state = state.copyWith(isLoading: false, success: true);
          _ref.invalidate(membersInsuranceProvider);
          return true;
        },
      );
    } else {
      // Crear
      final result = await _create(CreateInsuranceParams(
        memberId: memberId,
        insuranceType: insuranceType,
        startDate: startDate,
        endDate: endDate,
        policyNumber: policyNumber,
        providerName: providerName,
        coverageAmount: coverageAmount,
        evidenceFilePath: file?.path,
        evidenceFileName: file?.name,
        evidenceMimeType: mimeType,
      ));

      return result.fold(
        (failure) {
          state =
              state.copyWith(isLoading: false, errorMessage: failure.message);
          return false;
        },
        (_) {
          state = state.copyWith(isLoading: false, success: true);
          _ref.invalidate(membersInsuranceProvider);
          return true;
        },
      );
    }
  }

  void reset() => state = const InsuranceFormState();
}

final insuranceFormNotifierProvider = StateNotifierProvider.autoDispose<
    InsuranceFormNotifier, InsuranceFormState>(
  (ref) => InsuranceFormNotifier(
    create: ref.read(createInsuranceUseCaseProvider),
    update: ref.read(updateInsuranceUseCaseProvider),
    ref: ref,
  ),
);

// ── MIME type helper ─────────────────────────────────────────────────────────

/// Determina el tipo MIME a partir de la extensión del archivo.
String _mimeFromPath(String path) {
  final ext = path.split('.').last.toLowerCase();
  switch (ext) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'pdf':
      return 'application/pdf';
    default:
      return 'application/octet-stream';
  }
}
