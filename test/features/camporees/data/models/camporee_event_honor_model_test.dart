import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/camporees/data/models/camporee_event_model.dart';

void main() {
  group('CamporeeEventModel honors', () {
    Map<String, dynamic> eventJson({Object? honors}) {
      return {
        'camporee_event_id': 1,
        'title': 'Amarres',
        'max_points': 100,
        'min_points': 0,
        'day_number': 1,
        'display_category': 'logistico',
        'status': 'programado',
        'participants_mode': 'count',
        if (honors != null) 'honors': honors,
      };
    }

    test('parses preparation specialties with material url', () {
      final model = CamporeeEventModel.fromJson(
        eventJson(
          honors: [
            {
              'honor_id': 42,
              'name': 'Nudos',
              'honor_image': 'https://cdn.example/nudos.png',
              'material_url': 'https://cdn.example/nudos.pdf',
              'category_name': 'Actividades recreativas',
              'skill_level': 1,
              'active': true,
            },
          ],
        ),
      );

      expect(model.honors, hasLength(1));
      final honor = model.honors.first.toEntity();
      expect(honor.honorId, 42);
      expect(honor.name, 'Nudos');
      expect(honor.materialUrl, 'https://cdn.example/nudos.pdf');
      expect(honor.categoryName, 'Actividades recreativas');
      expect(honor.hasMaterial, isTrue);
    });

    test('missing honors becomes an empty list', () {
      final model = CamporeeEventModel.fromJson(eventJson());
      expect(model.honors, isEmpty);
      expect(model.toEntity().honors, isEmpty);
    });

    test('honor without pdf is consultable but has no material', () {
      final honor = CamporeeEventHonorModel.fromJson({
        'honor_id': 7,
        'name': 'Orientación',
        'material_url': '  ',
      }).toEntity();

      expect(honor.hasMaterial, isFalse);
    });
  });

  group('CamporeeEventModel attachments', () {
    test('parses attachments and drops the ones without url', () {
      final model = CamporeeEventModel.fromJson({
        'camporee_event_id': 7,
        'title': 'Marcha y orden cerrado',
        'max_points': 500,
        'min_points': 0,
        'day_number': 3,
        'display_category': 'competencia',
        'status': 'publicado',
        'participants_mode': 'count',
        'attachments': [
          {
            'attachment_id': 'a-1',
            'file_name': 'reglamento.pdf',
            'mime_type': 'application/pdf',
            'size_bytes': 245760,
            'url': 'https://r2.example/signed/reglamento.pdf',
          },
          {
            'attachment_id': 'a-2',
            'file_name': 'mapa.png',
            'mime_type': 'image/png',
            'size_bytes': 1048576,
            'url': '',
          },
        ],
      });

      final event = model.toEntity();
      expect(event.attachments, hasLength(1));
      final pdf = event.attachments.single;
      expect(pdf.attachmentId, 'a-1');
      expect(pdf.isPdf, isTrue);
      expect(pdf.isImage, isFalse);
      expect(pdf.sizeBytes, 245760);
    });

    test('an event without attachments parses to an empty list', () {
      final model = CamporeeEventModel.fromJson({
        'camporee_event_id': 8,
        'title': 'Fogata',
        'max_points': 0,
        'min_points': 0,
        'day_number': 2,
        'display_category': 'social',
        'status': 'publicado',
        'participants_mode': 'count',
      });
      expect(model.toEntity().attachments, isEmpty);
    });
  });
}
