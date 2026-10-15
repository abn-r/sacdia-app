import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/honors/presentation/utils/evidence_url.dart';

void main() {
  group('isPdfEvidenceUrl', () {
    test('reads the path, not the end of the string', () {
      expect(isPdfEvidenceUrl('https://h.io/a/b.pdf'), isTrue);
      expect(
        isPdfEvidenceUrl('https://h.io/a/B.PDF?X-Amz-Signature=x'),
        isTrue,
      );
      expect(isPdfEvidenceUrl('https://h.io/a/b.pdf#page=2'), isTrue);
      expect(isPdfEvidenceUrl('batches/b1/sealed/f1.pdf'), isTrue);
    });

    test('keeps the legacy /pdf segment', () {
      expect(isPdfEvidenceUrl('https://h.io/pdf/123'), isTrue);
    });

    test('images are not PDFs, even with .pdf in the query', () {
      expect(isPdfEvidenceUrl('https://h.io/a/b.jpg?x=1'), isFalse);
      expect(isPdfEvidenceUrl('https://h.io/a/b.png?name=file.pdf'), isFalse);
      expect(isPdfEvidenceUrl(''), isFalse);
    });
  });

  group('isFetchableEvidenceUrl', () {
    test('only http(s) links can be downloaded', () {
      expect(isFetchableEvidenceUrl('https://h.io/a.pdf?x=1'), isTrue);
      expect(isFetchableEvidenceUrl('http://h.io/a.jpg'), isTrue);
      expect(isFetchableEvidenceUrl('batches/b1/sealed/f1.pdf'), isFalse);
      expect(isFetchableEvidenceUrl(''), isFalse);
    });
  });
}
