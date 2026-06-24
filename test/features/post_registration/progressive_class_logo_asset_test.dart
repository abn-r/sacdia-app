import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/post_registration/data/models/class_model.dart';
import 'package:sacdia_app/features/post_registration/presentation/utils/progressive_class_logo_asset.dart';

void main() {
  group('ClassModel assetCode', () {
    test('parses asset_code from API payload', () {
      final progressiveClass = ClassModel.fromJson({
        'class_id': 7,
        'name': 'Amigo',
        'club_type_id': 2,
        'asset_code': 'CQ-01',
      });

      expect(progressiveClass.assetCode, 'CQ-01');
    });
  });

  group('progressiveClassLogoAsset', () {
    test('uses backend asset_code when available', () {
      const progressiveClass = ClassModel(
        id: 9,
        name: 'Explorador',
        clubTypeId: 2,
        assetCode: 'CQ-03',
      );

      expect(
        progressiveClassLogoAsset(progressiveClass),
        'assets/img/logos-clases/CQ-03.png',
      );
    });

    test('normalizes lowercase backend asset_code', () {
      const progressiveClass = ClassModel(
        id: 13,
        name: 'Guía Mayor',
        clubTypeId: 3,
        assetCode: 'gm-01',
      );

      expect(
        progressiveClassLogoAsset(progressiveClass),
        'assets/img/logos-clases/GM-01.png',
      );
    });

    test('falls back to class name for older payloads', () {
      const progressiveClass = ClassModel(
        id: 3,
        name: 'Abejitas Industriosas',
        clubTypeId: 1,
      );

      expect(
        progressiveClassLogoAsset(progressiveClass),
        'assets/img/logos-clases/AV-03.png',
      );
    });

    test('ignores invalid asset_code and falls back to class name', () {
      const progressiveClass = ClassModel(
        id: 10,
        name: 'Orientador',
        clubTypeId: 2,
        assetCode: 'bad-code',
      );

      expect(
        progressiveClassLogoAsset(progressiveClass),
        'assets/img/logos-clases/CQ-04.png',
      );
    });
  });
}
