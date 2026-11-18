import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../core/widgets/sac_image_viewer.dart';
import '../../../../core/widgets/sac_network_image.dart';
import '../../../../core/widgets/sac_pressable.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../../core/widgets/status_progress/sac_grouped_section.dart';
import '../../domain/entities/inventory_item.dart';
import '../providers/inventory_providers.dart';
import '../widgets/condition_badge.dart';
import '../widgets/condition_style.dart';
import '../widgets/inventory_item_actions.dart';

/// Detail of one inventory item.
///
/// The top bar carries the item name and the "more" menu (edit, change state,
/// delete). Below: the photos, the condition with the piece count and total
/// value, and label-value groups. A value that was never filled in reads
/// "Sin registrar" in gray.
class InventoryItemDetailView extends ConsumerWidget {
  final InventoryItem item;

  const InventoryItemDetailView({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManage = ref.watch(canManageInventoryProvider).value ?? false;
    final detail =
        ref.watch(inventoryItemDetailProvider(item.id)).value ?? item;
    final c = context.sac;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: detail.name,
        backgroundColor: c.background,
        frosted: true,
        actions: [
          if (canManage)
            SacPressable(
              listenOnly: true,
              child: IconButton(
                key: const ValueKey('inventory-detail-more'),
                enableFeedback: false,
                tooltip: 'inventory.view.more_options'.tr(),
                onPressed: () => _openActions(context, ref, detail),
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedMoreHorizontal,
                  size: 22,
                  color: c.textSecondary,
                ),
              ),
            ),
        ],
      ),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => SingleChildScrollView(
            padding: SacTopBar.paddingBelowBar(
              context,
              const EdgeInsets.only(top: 8, bottom: 32),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Hero(item: detail),
                _Summary(item: detail),
                _DetailsGroup(item: detail),
                _NotesGroup(item: detail),
                _RecordGroup(item: detail),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openActions(
    BuildContext context,
    WidgetRef ref,
    InventoryItem detail,
  ) async {
    final action = await showInventoryItemActionsSheet(
      context,
      item: detail,
      canManage: true,
      includeView: false,
    );
    if (action == null || !context.mounted) return;
    final deleted = await runInventoryItemAction(
      context,
      ref,
      item: detail,
      action: action,
    );
    if (deleted && context.mounted) Navigator.pop(context);
  }
}

// ── Hero ────────────────────────────────────────────────────────────────────────

class _Hero extends StatefulWidget {
  final InventoryItem item;

  const _Hero({required this.item});

  static const double height = 210;

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> {
  int _page = 0;

  List<String> get _urls {
    final fromEvidence = widget.item.evidences
        .map((e) => e.url)
        .where((u) => u.isNotEmpty)
        .toList();
    if (fromEvidence.isNotEmpty) return fromEvidence;
    final photo = widget.item.photoUrl;
    return photo != null && photo.isNotEmpty ? [photo] : const [];
  }

  @override
  Widget build(BuildContext context) {
    final urls = _urls;
    final c = context.sac;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        child: SizedBox(
          height: _Hero.height,
          child: urls.isEmpty
              ? _HeroPlaceholder(condition: widget.item.condition)
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    PageView.builder(
                      key: const ValueKey('inventory-hero-pages'),
                      itemCount: urls.length,
                      onPageChanged: (page) => setState(() => _page = page),
                      itemBuilder: (context, index) => Semantics(
                        button: true,
                        image: true,
                        label: widget.item.name,
                        child: GestureDetector(
                          onTap: () => SacImageViewer.show(
                            context,
                            imageUrl: urls[index],
                            imageUrls: urls,
                            initialIndex: index,
                            title: widget.item.name,
                          ),
                          child: SacNetworkImage(
                            imageUrl: urls[index],
                            fit: BoxFit.cover,
                            memCacheWidth: 1200,
                            errorWidget: (_, __, ___) => _HeroPlaceholder(
                              condition: widget.item.condition,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (urls.length > 1)
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: Semantics(
                          label: 'inventory.detail.photo_counter'.tr(
                            namedArgs: {
                              'current': '${_page + 1}',
                              'total': '${urls.length}',
                            },
                          ),
                          excludeSemantics: true,
                          child: Container(
                            key: const ValueKey('inventory-hero-counter'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              // Scrim over a photo: stays dark in both themes.
                              color: c.barrierColor,
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusFull),
                            ),
                            child: Text(
                              '${_page + 1} / ${urls.length}',
                              style: const TextStyle(
                                fontSize: SacFontSize.bodySmall,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _HeroPlaceholder extends StatelessWidget {
  final ItemCondition condition;

  const _HeroPlaceholder({required this.condition});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      key: const ValueKey('inventory-hero-placeholder'),
      color: condition.container(c),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HugeIcon(
            icon: condition.icon,
            size: 52,
            color: condition.onContainer(c),
          ),
          const SizedBox(height: 8),
          Text(
            'inventory.detail.no_photo'.tr(),
            style: TextStyle(
              fontSize: SacFontSize.bodyMedium,
              color: condition.onContainer(c),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Summary ─────────────────────────────────────────────────────────────────────

/// One condition badge and "N piezas · valor total $X".
class _Summary extends StatelessWidget {
  final InventoryItem item;

  const _Summary({required this.item});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final pieces = 'inventory.view.pieces'.plural(item.quantity, name: 'count');
    final value = item.estimatedValue;
    final text = value == null
        ? pieces
        : '$pieces · ${'inventory.detail.total_value'.tr(
            namedArgs: {'value': SacMoney.format(value * item.quantity)},
          )}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConditionBadge(condition: item.condition),
          Text(
            text,
            style: TextStyle(
              fontSize: SacFontSize.titleSmall,
              color: c.textSecondary,
              fontFeatures: SacMoney.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Groups ──────────────────────────────────────────────────────────────────────

class _DetailsGroup extends StatelessWidget {
  final InventoryItem item;

  const _DetailsGroup({required this.item});

  @override
  Widget build(BuildContext context) {
    final date = item.purchaseDate;
    final value = item.estimatedValue;
    final assignedTo = item.assignedTo?.trim();

    return SacGroupedSection(
      label: 'inventory.detail.details_title'.tr(),
      dividerIndent: 16,
      children: [
        _LabelValueRow(
          label: 'inventory.detail.category'.tr(),
          value: item.category.name,
        ),
        _LabelValueRow(
          label: 'inventory.detail.location'.tr(),
          value: _text(item.location),
        ),
        _LabelValueRow(
          label: 'inventory.detail.value_each'.tr(),
          value: value == null ? null : SacMoney.format(value),
        ),
        _LabelValueRow(
          label: 'inventory.detail.acquired'.tr(),
          value: date == null
              ? null
              : DateFormat.yMMMd(context.locale.toString()).format(date),
        ),
        _LabelValueRow(
          label: 'inventory.detail.serial_label'.tr(),
          value: _text(item.serialNumber),
        ),
        if (assignedTo != null && assignedTo.isNotEmpty)
          _LabelValueRow(
            label: 'inventory.detail.assigned_to'.tr(),
            value: assignedTo,
          ),
      ],
    );
  }
}

class _NotesGroup extends StatelessWidget {
  final InventoryItem item;

  const _NotesGroup({required this.item});

  @override
  Widget build(BuildContext context) {
    final description = _text(item.description);
    final notes = _text(item.notes);
    if (description == null && notes == null) return const SizedBox.shrink();

    return SacGroupedSection(
      label: 'inventory.detail.notes'.tr(),
      count: 0,
      action: const SizedBox.shrink(),
      dividerIndent: 16,
      children: [
        if (description != null) _TextBlock(text: description),
        if (notes != null) _TextBlock(text: notes),
      ],
    );
  }
}

/// Who registered the item and when.
class _RecordGroup extends StatelessWidget {
  final InventoryItem item;

  const _RecordGroup({required this.item});

  @override
  Widget build(BuildContext context) {
    final modifiedAt = item.modifiedAt;
    final modifiedBy = _text(item.modifiedByName);

    return SacGroupedSection(
      label: 'inventory.detail.record_title'.tr(),
      action: const SizedBox.shrink(),
      dividerIndent: 16,
      children: [
        _LabelValueRow(
          label: 'inventory.detail.registered_by'.tr(),
          value: _text(item.registeredByName),
        ),
        _LabelValueRow(
          label: 'inventory.detail.registered_at'.tr(),
          value: _formatDateTime(context, item.registeredAt),
        ),
        if (modifiedAt != null || modifiedBy != null)
          _LabelValueRow(
            label: 'inventory.detail.last_modified'.tr(),
            value: [
              modifiedBy,
              if (modifiedAt != null) _formatDateTime(context, modifiedAt),
            ].whereType<String>().join(' · '),
          ),
      ],
    );
  }
}

String? _text(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String _formatDateTime(BuildContext context, DateTime value) =>
    DateFormat.yMMMd(context.locale.toString())
        .add_Hm()
        .format(value.toLocal());

/// Label on the left, value on the right. A null value reads "Sin registrar"
/// in gray text (never a dash).
class _LabelValueRow extends StatelessWidget {
  final String label;
  final String? value;

  const _LabelValueRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final text = value;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(
                fontSize: SacFontSize.titleSmall,
                color: c.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: text == null
                ? Text(
                    'inventory.detail.not_recorded'.tr(),
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: SacFontSize.titleSmall,
                      color: c.textTertiary,
                    ),
                  )
                : Text(
                    text,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: SacFontSize.titleSmall,
                      fontWeight: FontWeight.w600,
                      color: c.text,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TextBlock extends StatelessWidget {
  final String text;

  const _TextBlock({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          text,
          style: TextStyle(
            fontSize: SacFontSize.titleSmall,
            height: 1.45,
            color: context.sac.text,
          ),
        ),
      ),
    );
  }
}
