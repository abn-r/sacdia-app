import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../providers/dio_provider.dart';
import '../../data/datasources/faq_local_data_source.dart';
import '../../data/datasources/support_remote_data_source.dart';
import '../../data/repositories/support_repository_impl.dart';
import '../../domain/entities/faq_item.dart';
import '../../domain/entities/support_report.dart';
import '../../domain/repositories/support_repository.dart';

// ── Infrastructure providers ──────────────────────────────────────────────────

final faqLocalDataSourceProvider = Provider<FaqLocalDataSource>((ref) {
  return FaqLocalDataSourceImpl();
});

final supportRemoteDataSourceProvider =
    Provider<SupportRemoteDataSource>((ref) {
  return SupportRemoteDataSourceImpl(
    dio: ref.read(dioProvider),
    baseUrl: ref.read(apiBaseUrlProvider),
  );
});

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  return SupportRepositoryImpl(
    faqLocal: ref.read(faqLocalDataSourceProvider),
    remote: ref.read(supportRemoteDataSourceProvider),
    networkInfo: ref.read(networkInfoProvider),
  );
});

// ── FAQ ───────────────────────────────────────────────────────────────────────

/// Carga el FAQ una vez por sesión (el asset no cambia en runtime).
final faqItemsProvider = FutureProvider<List<FaqItem>>((ref) async {
  final repo = ref.read(supportRepositoryProvider);
  final either = await repo.loadFaq();
  return either.fold(
    (failure) => throw Exception(failure.message),
    (items) => items,
  );
});

/// Texto de búsqueda del FAQ — se consume desde FaqView.
final faqSearchQueryProvider = StateProvider<String>((ref) => '');

/// FAQ filtrado por el query actual.
final filteredFaqItemsProvider = Provider<AsyncValue<List<FaqItem>>>((ref) {
  final itemsAsync = ref.watch(faqItemsProvider);
  final query = ref.watch(faqSearchQueryProvider);
  return itemsAsync.whenData((items) {
    if (query.trim().isEmpty) return items;
    return items.where((i) => i.matches(query)).toList(growable: false);
  });
});

// ── Device info ──────────────────────────────────────────────────────────────

/// Información del dispositivo capturada vía `device_info_plus` +
/// `package_info_plus`. Se envía junto con cada reporte.
final deviceReportInfoProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final pkg = await PackageInfo.fromPlatform();
  final plugin = DeviceInfoPlugin();

  String platform = 'unknown';
  String osVersion = 'unknown';
  String model = 'unknown';

  try {
    if (Platform.isIOS) {
      platform = 'ios';
      final info = await plugin.iosInfo;
      osVersion = info.systemVersion;
      model = info.utsname.machine;
    } else if (Platform.isAndroid) {
      platform = 'android';
      final info = await plugin.androidInfo;
      osVersion = 'Android ${info.version.release} (SDK ${info.version.sdkInt})';
      model = '${info.manufacturer} ${info.model}';
    } else if (Platform.isMacOS) {
      platform = 'macos';
      final info = await plugin.macOsInfo;
      osVersion = info.osRelease;
      model = info.model;
    }
  } catch (_) {
    // device_info_plus puede fallar en emuladores/web — caemos al default.
  }

  return {
    'platform': platform,
    'osVersion': osVersion,
    'model': model,
    'appVersion': pkg.version,
    'buildNumber': pkg.buildNumber,
  };
});

// ── Report submission ────────────────────────────────────────────────────────

/// Estado de envío de un reporte — la vista escucha este state para mostrar
/// loader / error / éxito.
class SupportReportSubmitState {
  final bool isSubmitting;
  final String? errorMessage;
  final SupportReportResult? success;

  const SupportReportSubmitState({
    this.isSubmitting = false,
    this.errorMessage,
    this.success,
  });

  SupportReportSubmitState copyWith({
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
    SupportReportResult? success,
    bool clearSuccess = false,
  }) {
    return SupportReportSubmitState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      success: clearSuccess ? null : success ?? this.success,
    );
  }
}

class SupportReportSubmitNotifier
    extends Notifier<SupportReportSubmitState> {
  @override
  SupportReportSubmitState build() => const SupportReportSubmitState();

  Future<void> submit(SupportReportDraft draft) async {
    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearSuccess: true,
    );

    final repo = ref.read(supportRepositoryProvider);
    final result = await repo.submitReport(draft);

    result.fold(
      (failure) {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: failure.message,
        );
      },
      (ok) {
        state = state.copyWith(isSubmitting: false, success: ok);
      },
    );
  }

  void reset() {
    state = const SupportReportSubmitState();
  }
}

final supportReportSubmitProvider = NotifierProvider<
    SupportReportSubmitNotifier, SupportReportSubmitState>(
  SupportReportSubmitNotifier.new,
);
