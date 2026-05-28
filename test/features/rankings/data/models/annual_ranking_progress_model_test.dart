import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/rankings/data/models/annual_ranking_progress_model.dart';

void main() {
  group('AnnualRankingProgressModel.fromJson', () {
    test('parses progress response JSON correctly', () {
      final model = AnnualRankingProgressModel.fromJson(_progressJson());
      final entity = model.toEntity();

      expect(entity.sectionId, 2);
      expect(entity.clubId, 7);
      expect(entity.clubName, 'Halcones');
      expect(entity.clubType.name, 'Aventureros');
      expect(entity.currentPoints, 7200);
      expect(entity.maxPoints, 10000);
      expect(entity.currentTier?.slug, 'plata');
      expect(entity.nextTier?.pointsToReach, 1300);
      expect(entity.components.first.key, 'annual_folder');
      expect(entity.pendingItems.first.statusLabelKey,
          'rankings.annual_progress.pending.status.pending_validation');
    });

    test('requires tier fields when tier is present', () {
      expect(
        () => RankingTierModel.fromJson(const {
          'slug': 'oro',
          'from_points': 8500,
          'to_points': 9499,
        }),
        throwsFormatException,
      );
    });

    test('requires component fields', () {
      expect(
        () => RankingComponentProgressModel.fromJson(const {
          'key': 'annual_folder',
          'earned_points': 4200,
          'max_points': 6000,
          'progress_percentage': 70,
        }),
        throwsFormatException,
      );
    });

    test('maps unknown pending status to safe fallback label key', () {
      final item = RankingPendingItemModel.fromJson(const {
        'type': 'annual_folder_section',
        'title': 'Actividades misioneras',
        'status': 'backend_new_status',
        'due_date': null,
        'action_label': 'Ver evidencia',
      });

      expect(item.status, 'backend_new_status');
      expect(item.statusLabelKey,
          'rankings.annual_progress.pending.status.pending_review');
    });
  });
}

Map<String, dynamic> _progressJson() => {
      'section_id': 2,
      'club_id': 7,
      'club_name': 'Halcones',
      'club_type': {
        'club_type_id': 1,
        'name': 'Aventureros',
      },
      'year': {
        'ecclesiastical_year_id': 1,
      },
      'current_points': 7200,
      'max_points': 10000,
      'progress_percentage': 72,
      'current_tier': {
        'name': 'Plata',
        'slug': 'plata',
        'from_points': 7000,
        'to_points': 8499,
        'points_to_reach': null,
      },
      'next_tier': {
        'name': 'Oro',
        'slug': 'oro',
        'from_points': 8500,
        'to_points': 9499,
        'points_to_reach': 1300,
      },
      'components': [
        {
          'key': 'annual_folder',
          'label': 'Carpeta anual',
          'earned_points': 4200,
          'max_points': 6000,
          'progress_percentage': 70,
        },
      ],
      'pending_items': [
        {
          'type': 'annual_folder_section',
          'title': 'Actividades misioneras',
          'status': 'pending_validation',
          'due_date': null,
          'action_label': 'Ver evidencia',
        },
      ],
    };
