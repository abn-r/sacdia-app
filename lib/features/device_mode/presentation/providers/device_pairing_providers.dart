import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/dio_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/device_pairing_remote_data_source.dart';
import '../../data/repositories/device_pairing_repository_impl.dart';
import '../../domain/repositories/device_pairing_repository.dart';
import '../../domain/usecases/pair_device.dart';

final devicePairingRepositoryProvider = Provider<DevicePairingRepository>(
  (ref) => DevicePairingRepositoryImpl(
    remoteDataSource: DevicePairingRemoteDataSourceImpl(
      dio: ref.read(dioProvider),
      baseUrl: ref.read(apiBaseUrlProvider),
    ),
  ),
);

final pairDeviceUseCaseProvider = Provider<PairDevice>(
  (ref) => PairDevice(ref.read(devicePairingRepositoryProvider)),
);
