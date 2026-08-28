import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/resources/domain/entities/resource.dart';
import 'package:sacdia_app/features/resources/presentation/utils/resource_preview.dart';

void main() {
  group('videoPreviewUrl', () {
    test('should resolve watch, short, embed and youtu.be URLs', () {
      expect(
        videoPreviewUrl('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
        'https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
      );
      expect(
        videoPreviewUrl('https://youtu.be/dQw4w9WgXcQ'),
        'https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
      );
      expect(
        videoPreviewUrl('https://www.youtube.com/embed/dQw4w9WgXcQ'),
        'https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
      );
      expect(
        videoPreviewUrl('https://www.youtube.com/shorts/dQw4w9WgXcQ'),
        'https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
      );
    });

    test('should return null for empty or non-YouTube URLs', () {
      expect(videoPreviewUrl(null), isNull);
      expect(videoPreviewUrl(''), isNull);
      expect(videoPreviewUrl('https://vimeo.com/123'), isNull);
    });
  });

  group('resourceWantsSignedPreview', () {
    Resource resource({
      String type = 'image',
      String? signedUrl,
      String? mime,
    }) {
      return Resource(
        resourceId: 'r1',
        title: 'T',
        resourceType: type,
        scopeLevel: 'system',
        signedUrl: signedUrl,
        fileMimeType: mime,
        createdAt: DateTime(2026, 1, 1),
      );
    }

    test('should fetch for images without a signed URL', () {
      expect(resourceWantsSignedPreview(resource()), isTrue);
    });

    test('should skip fetch when signed URL is already present', () {
      expect(
        resourceWantsSignedPreview(resource(signedUrl: 'https://cdn/x.jpg')),
        isFalse,
      );
    });

    test('should fetch documents that are actually images', () {
      expect(
        resourceWantsSignedPreview(
          resource(type: 'document', mime: 'image/png'),
        ),
        isTrue,
      );
    });

    test('should skip audio and text', () {
      expect(resourceWantsSignedPreview(resource(type: 'audio')), isFalse);
      expect(resourceWantsSignedPreview(resource(type: 'text')), isFalse);
    });
  });
}
