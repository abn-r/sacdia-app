import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/inventory/data/datasources/inventory_remote_data_source.dart';
import 'package:sacdia_app/features/inventory/domain/entities/inventory_item.dart';

void main() {
  group('InventoryRemoteDataSourceImpl', () {
    test('sends backend inventory contract when creating an item', () async {
      late RequestOptions captured;
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            captured = options;
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 201,
                data: const {
                  'status': 'success',
                  'data': {
                    'inventory_id': 15,
                    'name': 'Carpas',
                    'amount': 2,
                    'category': {'category_id': 1, 'name': 'Camping'},
                    'created_at': '2026-06-18T22:48:04.568Z',
                  },
                },
              ),
            );
          },
        ),
      );

      final dataSource = InventoryRemoteDataSourceImpl(
        dio: dio,
        baseUrl: 'https://api.test/api/v1',
      );

      await dataSource.createItem(
        clubId: 42,
        instanceType: 'pathf',
        name: 'Carpas',
        categoryId: 1,
        quantity: 2,
        condition: ItemCondition.bueno,
      );

      expect(captured.path,
          'https://api.test/api/v1/inventory/clubs/42/inventory');
      expect(captured.data, {
        'name': 'Carpas',
        'inventory_category_id': 1,
        'amount': 2,
        'instanceType': 'pathf',
        'condition': 'bueno',
      });
    });

    test('sends condition and extended fields when creating an item', () async {
      late RequestOptions captured;
      final dataSource = InventoryRemoteDataSourceImpl(
        dio: _captureDio((o) => captured = o, statusCode: 201),
        baseUrl: 'https://api.test/api/v1',
      );

      await dataSource.createItem(
        clubId: 42,
        instanceType: 'pathf',
        name: 'Brújula',
        categoryId: 4,
        quantity: 2,
        condition: ItemCondition.regular,
        serialNumber: 'SN-1',
        purchaseDate: DateTime(2026, 3, 5),
        estimatedValue: 350.5,
        location: 'Bodega',
        assignedTo: 'Ana',
        notes: 'Con estuche',
      );

      expect(captured.data, {
        'name': 'Brújula',
        'inventory_category_id': 4,
        'amount': 2,
        'instanceType': 'pathf',
        'condition': 'regular',
        'serial_number': 'SN-1',
        'purchase_date': '2026-03-05',
        'estimated_value': 350.5,
        'location': 'Bodega',
        'assigned_to': 'Ana',
        'notes': 'Con estuche',
      });
    });

    test('sends cleared optional fields as null when updating', () async {
      late RequestOptions captured;
      final dataSource = InventoryRemoteDataSourceImpl(
        dio: _captureDio((o) => captured = o),
        baseUrl: 'https://api.test/api/v1',
      );

      await dataSource.updateItem(
        itemId: 15,
        name: 'Carpas',
        categoryId: 1,
        quantity: 3,
        condition: ItemCondition.malo,
        location: 'Bodega',
      );

      expect(captured.method, 'PATCH');
      expect(captured.path, 'https://api.test/api/v1/inventory/inventory/15');
      expect(captured.data, {
        'name': 'Carpas',
        'inventory_category_id': 1,
        'amount': 3,
        'condition': 'malo',
        'description': null,
        'serial_number': null,
        'purchase_date': null,
        'estimated_value': null,
        'location': 'Bodega',
        'assigned_to': null,
        'notes': null,
      });
    });

    test('uploads evidence as multipart file', () async {
      late RequestOptions captured;
      final tempFile = File(
        '${Directory.systemTemp.path}/inventory-evidence-test.jpg',
      )..writeAsBytesSync([0xff, 0xd8, 0xff, 0x00]);

      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            captured = options;
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 201,
                data: const {
                  'status': 'success',
                  'data': {
                    'evidence_id': 7,
                    'inventory_id': 15,
                    'url': 'https://cdn.test/evidence.jpg',
                    'file_name': 'evidence.jpg',
                    'file_type': 'image/jpeg',
                    'uploaded_at': '2026-06-18T22:48:04.568Z',
                  },
                },
              ),
            );
          },
        ),
      );

      final dataSource = InventoryRemoteDataSourceImpl(
        dio: dio,
        baseUrl: 'https://api.test/api/v1',
      );

      final result = await dataSource.uploadEvidence(
        itemId: 15,
        filePath: tempFile.path,
        fileName: 'evidence.jpg',
        mimeType: 'image/jpeg',
      );

      expect(captured.path,
          'https://api.test/api/v1/inventory/inventory/15/evidences');
      expect(captured.data, isA<FormData>());
      expect(result.id, 7);
      expect(result.fileType, 'image/jpeg');

      tempFile.deleteSync();
    });
  });
}

Dio _captureDio(
  void Function(RequestOptions options) onCapture, {
  int statusCode = 200,
}) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        onCapture(options);
        handler.resolve(
          Response<Map<String, dynamic>>(
            requestOptions: options,
            statusCode: statusCode,
            data: const {
              'status': 'success',
              'data': {
                'inventory_id': 15,
                'name': 'Carpas',
                'amount': 2,
                'category': {'category_id': 1, 'name': 'Camping'},
                'created_at': '2026-06-18T22:48:04.568Z',
              },
            },
          ),
        );
      },
    ),
  );
  return dio;
}
