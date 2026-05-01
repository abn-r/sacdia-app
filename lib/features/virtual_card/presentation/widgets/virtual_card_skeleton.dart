import 'dart:math' as math;

import 'package:flutter/material.dart';

class VirtualCardSkeleton extends StatelessWidget {
  const VirtualCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final avatarSize = (constraints.maxHeight * 0.18).clamp(76.0, 108.0);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _bar(width: 92, height: 30, color: bg.withValues(alpha: 0.8)),
                  _bar(width: 64, height: 30, color: bg.withValues(alpha: 0.8)),
                ],
              ),
              const SizedBox(height: 20),
              Center(
                child: _circle(
                  size: avatarSize,
                  color: bg.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: _bar(
                  width: 180,
                  height: 22,
                  color: bg.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: _bar(
                  width: 140,
                  height: 14,
                  color: bg.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 18),
              _bar(
                  width: double.infinity,
                  height: 1,
                  color: bg.withValues(alpha: 0.7)),
              const SizedBox(height: 12),
              _bar(width: 120, height: 14, color: bg.withValues(alpha: 0.8)),
              const SizedBox(height: 8),
              _bar(width: 180, height: 18, color: bg.withValues(alpha: 0.85)),
              const SizedBox(height: 10),
              _bar(width: 90, height: 14, color: bg.withValues(alpha: 0.8)),
              const SizedBox(height: 8),
              _bar(width: 160, height: 18, color: bg.withValues(alpha: 0.85)),
              const SizedBox(height: 16),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, qrConstraints) {
                    final qrSize = math.min(
                      160.0,
                      math.min(qrConstraints.maxWidth, qrConstraints.maxHeight),
                    );

                    return Center(
                      child: _square(
                        size: qrSize,
                        color: bg.withValues(alpha: 0.75),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: _bar(
                  width: 132,
                  height: 18,
                  color: bg.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 18),
              _bar(
                  width: double.infinity,
                  height: 1,
                  color: bg.withValues(alpha: 0.7)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _bar(
                      width: 128, height: 12, color: bg.withValues(alpha: 0.8)),
                  _bar(
                      width: 78, height: 20, color: bg.withValues(alpha: 0.85)),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  static Widget _bar({
    required double width,
    required double height,
    required Color color,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }

  static Widget _circle({
    required double size,
    required Color color,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  static Widget _square({
    required double size,
    required Color color,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
    );
  }
}
