import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/config/cache_config.dart';
import 'package:sacdia_app/core/widgets/sac_network_image.dart';
import 'package:sacdia_app/core/widgets/sac_profile_image.dart';

void main() {
  test('stable key drops the signature and keeps the object path', () {
    expect(
      stableImageCacheKey(
        'https://cdn.example/user-profiles/photo-1.png?X-Amz-Signature=abc&X-Amz-Expires=300',
      ),
      'https://cdn.example/user-profiles/photo-1.png',
    );
    expect(
      stableImageCacheKey('https://cdn.example/honors/badge.svg'),
      'https://cdn.example/honors/badge.svg',
    );
  });

  test('a replaced photo is a different key from the previous object', () {
    const previous =
        'https://cdn.example/user-profiles/photo-user-1-1000.jpg?X-Amz-Signature=old';
    const next =
        'https://cdn.example/user-profiles/photo-user-1-2000.jpg?X-Amz-Signature=new';
    expect(stableImageCacheKey(previous), isNot(stableImageCacheKey(next)));
  });

  testWidgets('svg badges request the disk cache without the signature', (
    tester,
  ) async {
    String? seenKey;
    await tester.pumpWidget(
      MaterialApp(
        home: SacNetworkImage(
          imageUrl: 'https://cdn.example/honors/badge.svg?X-Amz-Signature=abc',
          width: 40,
          height: 40,
          loadSvgBytes: (url, cacheKey) async {
            seenKey = cacheKey;
            return Uint8List.fromList(
              '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10" viewBox="0 0 10 10"><rect width="10" height="10"/></svg>'
                  .codeUnits,
            );
          },
        ),
      ),
    );
    await tester.pump();

    expect(seenKey, 'https://cdn.example/honors/badge.svg');
    expect(find.byType(SvgPicture), findsOneWidget);
  });

  testWidgets('profile image uses the profile store and a stable key', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SacProfileImage(
          imageUrl:
              'https://cdn.example/user-profiles/photo-1.png?X-Amz-Signature=abc',
          width: 32,
          height: 32,
        ),
      ),
    );

    final cached = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(cached.cacheKey, 'https://cdn.example/user-profiles/photo-1.png');
    expect(cached.cacheManager, same(SacProfileCacheManager.instance));
  });
}
