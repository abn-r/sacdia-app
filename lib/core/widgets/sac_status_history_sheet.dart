import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';

/// One row in a status-history timeline.
class SacStatusHistoryEntry {
  const SacStatusHistoryEntry({
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    this.author,
    this.timestamp,
  });

  final String label;
  final String description;
  final dynamic icon;
  final Color color;
  final String? author;
  final DateTime? timestamp;
}

/// Shared chrome + timeline for requirement / evidence history sheets.
class SacStatusHistorySheet extends StatelessWidget {
  const SacStatusHistorySheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.entries,
    required this.emptyTitle,
    required this.emptyBody,
  });

  final String title;
  final String subtitle;
  final List<SacStatusHistoryEntry> entries;
  final String emptyTitle;
  final String emptyBody;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SacSheetHeader(
              title: title,
              subtitle: subtitle,
              showClose: true,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const HugeIcon(
                  icon: HugeIcons.strokeRoundedTime01,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
            ),
            Divider(height: 1, color: c.border),
            if (entries.isEmpty)
              _HistoryEmpty(title: emptyTitle, body: emptyBody)
            else
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: _TimelineList(entries: entries),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

Future<void> showSacStatusHistorySheet(
  BuildContext context, {
  required String title,
  required String subtitle,
  required List<SacStatusHistoryEntry> entries,
  required String emptyTitle,
  required String emptyBody,
}) {
  return showSacSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => SacStatusHistorySheet(
      title: title,
      subtitle: subtitle,
      entries: entries,
      emptyTitle: emptyTitle,
      emptyBody: emptyBody,
    ),
  );
}

class _HistoryEmpty extends StatelessWidget {
  const _HistoryEmpty({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedTime01,
            size: 48,
            color: c.textTertiary,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: c.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: TextStyle(fontSize: 13, color: c.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _TimelineList extends StatelessWidget {
  const _TimelineList({required this.entries});

  final List<SacStatusHistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < entries.length; i++)
          _TimelineRow(
            entry: entries[i],
            isFirst: i == 0,
            isLast: i == entries.length - 1,
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.entry,
    required this.isFirst,
    required this.isLast,
  });

  final SacStatusHistoryEntry entry;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final dateFormat = DateFormat('d MMM yyyy · HH:mm', 'es');

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                if (!isFirst)
                  Expanded(
                    flex: 1,
                    child: Center(
                      child: Container(
                        width: 2,
                        color: entry.color.withValues(alpha: 0.35),
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 6),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: entry.color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: entry.color.withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: HugeIcon(
                      icon: entry.icon,
                      size: 15,
                      color: entry.color,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    flex: 3,
                    child: Center(
                      child: Container(
                        width: 2,
                        color: entry.color.withValues(alpha: 0.35),
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 6),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                top: isFirst ? 6 : 10,
                bottom: isLast ? 6 : 14,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: entry.color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: c.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  if (entry.author != null || entry.timestamp != null) ...[
                    const SizedBox(height: 6),
                    _MetaRow(
                      author: entry.author,
                      timestamp: entry.timestamp,
                      dateFormat: dateFormat,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.author,
    required this.timestamp,
    required this.dateFormat,
  });

  final String? author;
  final DateTime? timestamp;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          if (author != null) ...[
            HugeIcon(
              icon: HugeIcons.strokeRoundedUser02,
              size: 13,
              color: c.textTertiary,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                author!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: c.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          if (author != null && timestamp != null) ...[
            const SizedBox(width: 8),
            Container(
              width: 3,
              height: 3,
              decoration: BoxDecoration(
                color: c.textTertiary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (timestamp != null) ...[
            HugeIcon(
              icon: HugeIcons.strokeRoundedCalendar01,
              size: 13,
              color: c.textTertiary,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                dateFormat.format(timestamp!.toLocal()),
                style: TextStyle(
                  fontSize: 12,
                  color: c.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
