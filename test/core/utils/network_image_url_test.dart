import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/utils/network_image_url.dart';

void main() {
  group('isSvgNetworkUrl', () {
    test('detects .svg paths', () {
      expect(
        isSvgNetworkUrl(
          'https://pub-c8aa231ae66c46ff96fc5e811994d9d2.r2.dev/achievements/badge.svg',
        ),
        isTrue,
      );
      expect(isSvgNetworkUrl('badges/achievement-42.SVG'), isTrue);
    });

    test('ignores query and fragment', () {
      expect(
        isSvgNetworkUrl(
          'https://example.com/achievements/badge.svg?X-Amz-Signature=abc#frag',
        ),
        isTrue,
      );
    });

    test('rejects raster extensions', () {
      expect(isSvgNetworkUrl('https://example.com/badge.png'), isFalse);
      expect(isSvgNetworkUrl('https://example.com/badge.webp'), isFalse);
      expect(isSvgNetworkUrl('https://example.com/badge.jpg'), isFalse);
      expect(
        isSvgNetworkUrl('https://example.com/badge.png?format=svg'),
        isFalse,
      );
    });
  });
}
