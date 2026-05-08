import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/nominatim_remote_data_source.dart';

final nominatimRemoteDataSourceProvider = Provider<NominatimRemoteDataSource>(
  (ref) => NominatimRemoteDataSourceImpl(),
);
