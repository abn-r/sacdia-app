import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/coordinator/domain/entities/evidence_review_item.dart';

EvidenceFile _file(String url, {String? name, String? mimeType}) =>
    EvidenceFile(id: '1', url: url, name: name, mimeType: mimeType);

void main() {
  group('EvidenceFile', () {
    test('a signed URL keeps its extension behind the query', () {
      final file = _file(
        'https://files.example.com/folders/a/photo.JPG'
        '?X-Amz-Signature=abc&X-Amz-Expires=900',
      );

      expect(file.isImage, isTrue);
      expect(file.isPdf, isFalse);
    });

    test('a signed PDF URL is a PDF', () {
      final file = _file('https://files.example.com/a/report.pdf?sig=1');

      expect(file.isPdf, isTrue);
      expect(file.isImage, isFalse);
    });

    test('with no extension in the URL the file name decides', () {
      expect(
          _file('https://files.example.com/a/123', name: 'Foto.webp').isImage,
          isTrue);
      expect(_file('https://files.example.com/a/123', name: 'acta.pdf').isPdf,
          isTrue);
    });

    test('the mime type wins over a missing extension', () {
      expect(_file('https://x/1', mimeType: 'image/png').isImage, isTrue);
      expect(_file('https://x/1', mimeType: 'application/pdf').isPdf, isTrue);
    });

    test('a dot in a folder name is not an extension', () {
      final file = _file('https://x/v1.2/document');

      expect(file.isImage, isFalse);
      expect(file.isPdf, isFalse);
    });
  });
}
