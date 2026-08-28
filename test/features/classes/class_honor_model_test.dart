import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/classes/data/models/class_honor_model.dart';
import 'package:sacdia_app/features/classes/domain/entities/class_honor.dart';

void main() {
  group('ClassHonorModel', () {
    test('parses full JSON with nested honor and user_status', () {
      final model = ClassHonorModel.fromJson(const {
        'class_honor_id': 10,
        'relation_type': 'RECOMMENDED',
        'honor': {
          'honor_id': 55,
          'name': 'Primeros Auxilios',
          'honor_image': 'primeros-auxilios.png',
          'honors_category_id': 3,
          'skill_level': 1,
        },
        'user_status': 'APPROVED',
      });

      expect(model.classHonorId, 10);
      expect(model.relationType, ClassHonorRelationType.recommended);
      expect(model.honorId, 55);
      expect(model.honorName, 'Primeros Auxilios');
      expect(model.honorImage, contains('primeros-auxilios.png'));
      expect(model.honorCategoryId, 3);
      expect(model.honorSkillLevel, 1);
      expect(model.userStatus, 'APPROVED');
      expect(model.isCompletedByUser, isTrue);

      final entity = model.toEntity();
      expect(entity, isA<ClassHonor>());
      expect(entity.honorId, 55);
      expect(entity.honorName, 'Primeros Auxilios');
    });

    test('maps REQUIRED and ELECTIVE relation types', () {
      final required = ClassHonorModel.fromJson(const {
        'class_honor_id': 1,
        'relation_type': 'REQUIRED',
        'honor': {'honor_id': 2, 'name': 'Nudos'},
      });
      expect(required.relationType, ClassHonorRelationType.required);
      expect(required.userStatus, isNull);
      expect(required.isCompletedByUser, isFalse);

      final elective = ClassHonorModel.fromJson(const {
        'class_honor_id': 2,
        'relation_type': 'ELECTIVE',
        'honor': {'honor_id': 3, 'name': 'Pesca'},
      });
      expect(elective.relationType, ClassHonorRelationType.elective);
    });

    test('defaults relation type to recommended for unknown/missing values',
        () {
      final model = ClassHonorModel.fromJson(const {
        'class_honor_id': 3,
        'honor': {'honor_id': 4, 'name': 'Cocina'},
      });
      expect(model.relationType, ClassHonorRelationType.recommended);
    });

    test('leaves absolute honor_image URLs untouched', () {
      final model = ClassHonorModel.fromJson(const {
        'class_honor_id': 4,
        'relation_type': 'RECOMMENDED',
        'honor': {
          'honor_id': 5,
          'name': 'Natación',
          'honor_image': 'https://cdn.example.com/natacion.png',
        },
      });
      expect(model.honorImage, 'https://cdn.example.com/natacion.png');
    });

    test('parses module assignment and material_url', () {
      final model = ClassHonorModel.fromJson(const {
        'class_honor_id': 10,
        'relation_type': 'REQUIRED',
        'module_id': 12,
        'module_name': 'Vida al aire libre',
        'honor': {
          'honor_id': 55,
          'name': 'Nudos',
          'material_url': 'https://cdn.example.com/nudos.pdf',
        },
        'user_status': 'IN_PROGRESS',
      });

      expect(model.moduleId, 12);
      expect(model.moduleName, 'Vida al aire libre');
      expect(model.materialUrl, 'https://cdn.example.com/nudos.pdf');
      expect(model.hasMaterial, isTrue);
      expect(model.isEnrolled, isTrue);
      expect(model.isCompletedByUser, isFalse);
    });

    test('null module and missing material stay empty', () {
      final model = ClassHonorModel.fromJson(const {
        'class_honor_id': 11,
        'relation_type': 'RECOMMENDED',
        'module_id': null,
        'honor': {'honor_id': 9, 'name': 'Astronomía'},
      });

      expect(model.moduleId, isNull);
      expect(model.moduleName, isNull);
      expect(model.hasMaterial, isFalse);
      expect(model.isEnrolled, isFalse);
    });

    test('class carousel keeps module-anchored honors visible', () {
      final classLevel = ClassHonorModel.fromJson(const {
        'class_honor_id': 1,
        'relation_type': 'RECOMMENDED',
        'module_id': null,
        'honor': {'honor_id': 9, 'name': 'Astronomía'},
      }).toEntity();
      final moduleAnchored = ClassHonorModel.fromJson(const {
        'class_honor_id': 297,
        'relation_type': 'RECOMMENDED',
        'module_id': 95,
        'module_name': 'Desarrollo de habilidades',
        'honor': {'honor_id': 16, 'name': 'Amarres'},
      }).toEntity();

      expect(
        ClassHonor.forClassCarousel([classLevel, moduleAnchored]),
        [classLevel, moduleAnchored],
      );
    });

    test('user_status other than APPROVED is not treated as completed', () {
      final model = ClassHonorModel.fromJson(const {
        'class_honor_id': 5,
        'relation_type': 'RECOMMENDED',
        'honor': {'honor_id': 6, 'name': 'Campismo'},
        'user_status': 'in_progress',
      });
      expect(model.isCompletedByUser, isFalse);
    });
  });
}
