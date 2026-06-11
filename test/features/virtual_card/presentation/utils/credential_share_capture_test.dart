import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/virtual_card/presentation/utils/credential_share_capture.dart';

void main() {
  testWidgets('captures a repaint boundary even when it was just dirtied',
      (tester) async {
    final boundaryKey = GlobalKey();
    final stateKey = GlobalKey<_DirtyBoundaryState>();

    await tester.pumpWidget(
      MaterialApp(
        home: _DirtyBoundaryHost(
          key: stateKey,
          boundaryKey: boundaryKey,
        ),
      ),
    );

    stateKey.currentState!.markDirty();

    var encodedWhileDirty = true;
    final captureFuture = captureCredentialBoundaryPng(
      boundaryKey: boundaryKey,
      viewContext: tester.element(find.byType(_DirtyBoundaryHost)),
      pixelRatio: 1,
      encoder: (RenderRepaintBoundary boundary, double pixelRatio) async {
        encodedWhileDirty = boundary.debugNeedsPaint;
        return Uint8List.fromList(<int>[137, 80, 78, 71, 13, 10, 26, 10]);
      },
    );

    await tester.pump();
    await tester.pump();
    final bytes = await captureFuture.timeout(const Duration(seconds: 1));

    expect(encodedWhileDirty, isFalse);
    expect(bytes, isA<Uint8List>());
    expect(
      bytes.take(8).toList(),
      equals(<int>[137, 80, 78, 71, 13, 10, 26, 10]),
    );
  });
}

class _DirtyBoundaryHost extends StatefulWidget {
  const _DirtyBoundaryHost({super.key, required this.boundaryKey});

  final GlobalKey boundaryKey;

  @override
  State<_DirtyBoundaryHost> createState() => _DirtyBoundaryState();
}

class _DirtyBoundaryState extends State<_DirtyBoundaryHost> {
  var _color = Colors.red;

  void markDirty() {
    setState(() {
      _color = Colors.blue;
    });
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: widget.boundaryKey,
      child: ColoredBox(
        color: _color,
        child: const SizedBox(width: 120, height: 80),
      ),
    );
  }
}
