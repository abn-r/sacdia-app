import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/utils/date_formatter.dart';
import 'package:sacdia_app/features/master_honors/domain/entities/user_master_honor.dart';
import 'package:sacdia_app/features/master_honors/presentation/providers/master_honors_providers.dart';

import 'master_honor_badge.dart';

/// Strip horizontal de maestrías para la Tarjeta Virtual.
class MasterHonorBadgeStrip extends ConsumerWidget {
  final int? maxItems;

  const MasterHonorBadgeStrip({
    super.key,
    this.maxItems,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final honorsAsync = ref.watch(userMasterHonorsProvider);

    return honorsAsync.when(
      loading: () => const _MasterHonorStripSkeleton(),
      error: (_, __) => const SizedBox.shrink(),
      data: (honors) {
        if (honors.isEmpty) return const SizedBox.shrink();

        final visible = _orderedMasterHonors(honors);
        final limit = maxItems;
        final limited = limit == null || visible.length <= limit
            ? visible
            : visible.sublist(0, limit);

        return _MasterHonorStripContent(honors: limited);
      },
    );
  }
}

/// Historial de maestrías con estado y fechas en perfil.
class MasterHonorHistorySection extends ConsumerWidget {
  final bool showHeader;

  const MasterHonorHistorySection({
    super.key,
    this.showHeader = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final honorsAsync = ref.watch(userMasterHonorsProvider);

    return honorsAsync.when(
      loading: () => const _MasterHonorHistorySkeleton(),
      error: (error, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Text(
          'No fue posible cargar el historial de maestrías.',
          style: const TextStyle(color: Colors.red, fontSize: 13),
        ),
      ),
      data: (honors) {
        if (honors.isEmpty) {
          return const SizedBox.shrink();
        }

        final ordered = _orderedMasterHonors(honors);
        return Padding(
          key: const ValueKey('master-honor-history-data'),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showHeader) ...[
                Text(
                  'Maestrías',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _isDark(context)
                        ? AppColors.darkText
                        : AppColors.lightText,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              ...ordered.map(
                (honor) => _HistoryItem(honor: honor),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MasterHonorStripContent extends StatelessWidget {
  const _MasterHonorStripContent({required this.honors});

  final List<UserMasterHonor> honors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        width: double.infinity,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: honors
                .map(
                  (honor) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: MasterHonorBadge(
                      honor: honor,
                      compact: true,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  const _HistoryItem({required this.honor});

  final UserMasterHonor honor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        elevation: 0,
        color:
            _isDark(context) ? AppColors.darkSurface : AppColors.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color:
                _isDark(context) ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MasterHonorBadge(
                    honor: honor,
                    compact: true,
                    showStatus: false,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          honor.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        _StatusLine(honor: honor),
                        const SizedBox(height: 2),
                        if (_buildDateLines(honor).isNotEmpty)
                          ..._buildDateLines(honor).map(
                            (line) => Text(
                              line,
                              style: TextStyle(
                                fontSize: 12,
                                color: _isDark(context)
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                                height: 1.25,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _buildDateLines(UserMasterHonor honor) {
    final lines = <String>[];

    if (honor.awardedAt != null) {
      lines.add('Concedida: ${SacDateFormatter.date(honor.awardedAt)}');
    }
    if (honor.revokedAt != null) {
      lines.add('Revocada: ${SacDateFormatter.date(honor.revokedAt)}');
    }
    if (honor.recoveredAt != null) {
      lines.add('Recuperada: ${SacDateFormatter.date(honor.recoveredAt)}');
    }

    return lines;
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.honor});

  final UserMasterHonor honor;

  @override
  Widget build(BuildContext context) {
    final isCurrent = honor.isCurrent;
    final status = honor.displayStatusLabel.trim().isNotEmpty
        ? honor.displayStatusLabel
        : (isCurrent ? 'Vigente' : 'No vigente');
    final statusColor = isCurrent ? AppColors.secondary : AppColors.error;

    return Row(
      children: [
        Container(
          height: 8,
          width: 8,
          decoration: BoxDecoration(
            color: statusColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          status,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        if (honor.statusReason != null &&
            honor.statusReason!.trim().isNotEmpty) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              honor.statusReason!,
              style: TextStyle(
                fontSize: 11,
                color: _isDark(context)
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}

class _MasterHonorStripSkeleton extends StatelessWidget {
  const _MasterHonorStripSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: List.generate(
          3,
          (index) => Container(
            width: 120,
            height: 54,
            decoration: BoxDecoration(
              color: _isDark(context)
                  ? AppColors.darkSurfaceVariant
                  : AppColors.lightSurfaceVariant,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }
}

class _MasterHonorHistorySkeleton extends StatelessWidget {
  const _MasterHonorHistorySkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 110,
            height: 18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: _isDark(context)
                  ? AppColors.darkSurfaceVariant
                  : AppColors.lightSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          ...List.generate(
            2,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                height: 84,
                decoration: BoxDecoration(
                  color: _isDark(context)
                      ? AppColors.darkSurfaceVariant
                      : AppColors.lightSurfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

List<UserMasterHonor> _orderedMasterHonors(List<UserMasterHonor> honors) {
  final ordered = List<UserMasterHonor>.from(honors)
    ..sort((a, b) {
      if (a.isCurrent != b.isCurrent) {
        return a.isCurrent ? -1 : 1;
      }

      final aDate = _latestDate(a);
      final bDate = _latestDate(b);

      if (aDate == null && bDate == null) {
        return a.name.compareTo(b.name);
      }
      if (aDate == null) return 1;
      if (bDate == null) return -1;

      return bDate.compareTo(aDate);
    });

  return ordered;
}

DateTime? _latestDate(UserMasterHonor honor) {
  final dates = [
    honor.awardedAt,
    honor.revokedAt,
    honor.recoveredAt,
  ].whereType<DateTime>().toList();
  if (dates.isEmpty) return null;
  return dates.reduce((a, b) => a.isAfter(b) ? a : b);
}

bool _isDark(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark;
}
