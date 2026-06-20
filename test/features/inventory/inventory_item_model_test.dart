import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/inventory/data/models/inventory_item_model.dart';

void main() {
  group('InventoryItemModel.fromJson', () {
    test('parses backend amount as quantity', () {
      final item = InventoryItemModel.fromJson(const {
        'inventory_id': 10,
        'name': 'Carpas',
        'amount': 7,
        'category': {'category_id': 3, 'name': 'Camping'},
        'created_at': '2026-06-18T22:48:04.568Z',
      });

      expect(item.quantity, 7);
    });

    test('parses evidence photos and uses first evidence as photoUrl', () {
      final item = InventoryItemModel.fromJson(const {
        'inventory_id': 10,
        'name': 'Carpas',
        'amount': 7,
        'category': {'category_id': 3, 'name': 'Camping'},
        'created_at': '2026-06-18T22:48:04.568Z',
        'evidences': [
          {
            'evidence_id': 5,
            'inventory_id': 10,
            'url': 'https://cdn.test/carpa.jpg',
            'file_name': 'carpa.jpg',
            'file_type': 'image/jpeg',
            'file_size': 123,
            'uploaded_at': '2026-06-18T22:50:04.568Z',
          }
        ],
      });

      expect(item.evidences, hasLength(1));
      expect(item.evidences.first.fileName, 'carpa.jpg');
      expect(item.photoUrl, 'https://cdn.test/carpa.jpg');
    });

    test('parses created_by object as registeredByName', () {
      final item = InventoryItemModel.fromJson(const {
        'inventory_id': 10,
        'name': 'Carpas',
        'amount': 7,
        'category': {'category_id': 3, 'name': 'Camping'},
        'created_at': '2026-06-18T22:48:04.568Z',
        'created_by': {
          'user_id': 'user-abc',
          'name': 'Ana',
          'paternal_last_name': 'López',
        },
      });

      expect(item.registeredByName, 'Ana López');
    });

    test('parses created_by avatar url for registeredByAvatarUrl', () {
      final item = InventoryItemModel.fromJson(const {
        'inventory_id': 10,
        'name': 'Carpas',
        'amount': 7,
        'category': {'category_id': 3, 'name': 'Camping'},
        'created_at': '2026-06-18T22:48:04.568Z',
        'created_by': {
          'user_id': 'user-abc',
          'name': 'Ana',
          'paternal_last_name': 'López',
          'avatar_url': 'https://signed.example/ana.jpg',
        },
      });

      expect(item.registeredByAvatarUrl, 'https://signed.example/ana.jpg');
    });
  });
}
