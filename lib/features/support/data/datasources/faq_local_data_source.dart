import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/faq_item.dart';

/// Fuente local del FAQ. Lee el asset bundleado en `assets/support/faq.json`
/// (debe estar declarado en `pubspec.yaml`).
abstract class FaqLocalDataSource {
  Future<List<FaqItem>> loadAll();
}

class FaqLocalDataSourceImpl implements FaqLocalDataSource {
  static const _tag = 'FaqLocalDS';
  static const _assetPath = 'assets/support/faq.json';

  // Cache en memoria: el JSON es chico y no cambia durante la vida del proceso.
  List<FaqItem>? _cache;

  @override
  Future<List<FaqItem>> loadAll() async {
    final cached = _cache;
    if (cached != null) return cached;

    try {
      final raw = await rootBundle.loadString(_assetPath);
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final items = (decoded['items'] as List<dynamic>? ?? const [])
          .map((e) => FaqItem.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
      _cache = items;
      AppLogger.d('FAQ cargado: ${items.length} items', tag: _tag);
      return items;
    } catch (e, st) {
      AppLogger.e('Error cargando FAQ', tag: _tag, error: e, stackTrace: st);
      throw CacheException(
        message: tr('support.errors.faq_load_failed'),
      );
    }
  }
}
