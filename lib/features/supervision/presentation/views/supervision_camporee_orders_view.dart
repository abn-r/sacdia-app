import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/errors/forbidden.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/utils/money_format.dart';
import 'package:sacdia_app/core/widgets/sac_date_picker.dart';
import 'package:sacdia_app/core/widgets/sac_dropdown_field.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_list_row.dart';
import 'package:sacdia_app/core/widgets/sac_notice.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/core/widgets/sac_text_field.dart';
import 'package:sacdia_app/core/widgets/sac_tone.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_grouped_section.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_state_panel.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_status_style.dart';
import 'package:sacdia_app/features/activities/presentation/widgets/activity_form_widgets.dart'
    show showTimePickerSheet;
import 'package:sacdia_app/features/auth/domain/utils/authorization_utils.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/camporee_orders/domain/entities/camporee_order_offering.dart';
import 'package:sacdia_app/features/camporee_orders/domain/entities/camporee_order_product.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_camporee_orders.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_action_result.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_camporee_orders_providers.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_union_camporees_providers.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_actions.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_format.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_messages.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_plain_row.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_row_parts.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_scroll.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_segmented_control.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_status_chip.dart';

/// The two things set up for a camporee.
enum _Tab { orders, supplies }

/// Server limits of the supply forms.
const int _kSlotLabelMax = 80;
const int _kProductNameMax = 120;
const int _kMaxCentavos = 100000000;

/// Setup of a union camporee: the window in which clubs order merchandise and
/// what is on sale, and the supplies clubs can plan (cutoff, delivery times
/// and products). Every change saves on its own.
class SupervisionCamporeeOrdersView extends ConsumerStatefulWidget {
  const SupervisionCamporeeOrdersView({super.key, required this.camporeeId});

  /// Path parameter; anything that is not a camporee id shows the error state.
  final String camporeeId;

  @override
  ConsumerState<SupervisionCamporeeOrdersView> createState() =>
      _SupervisionCamporeeOrdersViewState();
}

class _SupervisionCamporeeOrdersViewState
    extends ConsumerState<SupervisionCamporeeOrdersView> {
  _Tab _tab = _Tab.orders;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final id = int.tryParse(widget.camporeeId);
    final title = 'supervision.union_camporees.orders_title'.tr();

    if (id == null) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: c.background,
        appBar: SacTopBar(title: title, frosted: true),
        body: SacFrostedVeil(
          child: SupervisionScroll(
            onRefresh: () async {},
            fill: true,
            child: SacErrorState(
              title: 'supervision.union_camporees.orders_error_title'.tr(),
              message: 'supervision.union_camporees.error_message'.tr(),
            ),
          ),
        ),
      );
    }

    final user = ref.watch(authNotifierProvider.select((v) => v.value));
    final canSupplies = hasCapability(user, 'camporee_supplies.configure');
    final tab = canSupplies ? _tab : _Tab.orders;
    final camporeeName =
        ref.watch(supervisionUnionCamporeeProvider(id)).value?.name.trim();

    final chips = canSupplies
        ? SupervisionSegmentedControl<_Tab>(
            selected: tab,
            onChanged: (value) => setState(() => _tab = value),
            segments: [
              SupervisionSegment(
                value: _Tab.orders,
                label: 'supervision.union_camporees.tab_orders'.tr(),
              ),
              SupervisionSegment(
                value: _Tab.supplies,
                label: 'supervision.union_camporees.tab_supplies'.tr(),
              ),
            ],
          )
        : null;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: title,
        subtitle:
            camporeeName == null || camporeeName.isEmpty ? null : camporeeName,
        frosted: true,
      ),
      body: SacFrostedVeil(
        child: switch (tab) {
          _Tab.orders => _OrdersTab(camporeeId: id, chips: chips),
          _Tab.supplies => _SuppliesTab(camporeeId: id, chips: chips),
        },
      ),
    );
  }
}

// ── Shared pieces ───────────────────────────────────────────────────────────

/// Text for a failed save: the app's own wording for the codes it knows.
String _saveError(SupervisionActionResult result) {
  final key = switch (result.errorCode) {
    'CAMPOREE_ORDER_FORBIDDEN' ||
    'CAMPOREE_SUPPLIES_FORBIDDEN' =>
      'error_forbidden',
    'CAMPOREE_ORDER_OFFERING_INVALID' => 'error_offering_invalid',
    'CAMPOREE_ORDER_PRODUCT_SCOPE_INVALID' => 'error_product_scope',
    'CAMPOREE_ORDER_OPTION_REQUIRED' => 'error_option_required',
    'CAMPOREE_SUPPLIES_PRICE_LOCKED' => 'error_price_locked',
    'CAMPOREE_SUPPLIES_CUTOFF_INVALID' => 'error_cutoff_invalid',
    _ => result.isForbidden ? 'error_forbidden' : null,
  };
  return key == null
      ? supervisionErrorMessage(result.errorMessage)
      : 'supervision.union_camporees.$key'.tr();
}

/// Pesos typed by hand ("120", "120.50", "120,5") to centavos; null when it
/// is not an amount.
int? _parseCentavos(String text) {
  final normalized = text.trim().replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  final pesos = double.tryParse(normalized);
  if (pesos == null || pesos.isNaN || pesos < 0) return null;
  final centavos = (pesos * 100).round();
  return centavos > _kMaxCentavos ? null : centavos;
}

/// Centavos as the text of a price field ("120" or "120.50").
String _pesosText(int centavos) {
  final whole = centavos ~/ 100;
  final cents = centavos % 100;
  return cents == 0 ? '$whole' : '$whole.${cents.toString().padLeft(2, '0')}';
}

final List<TextInputFormatter> _priceFormatters = [
  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
  LengthLimitingTextInputFormatter(10),
];

TimeOfDay _parseTime(String hhmm) {
  final parts = hhmm.split(':');
  final hour = parts.isNotEmpty ? int.tryParse(parts[0]) : null;
  final minute = parts.length > 1 ? int.tryParse(parts[1]) : null;
  return TimeOfDay(
    hour: (hour ?? 0).clamp(0, 23),
    minute: (minute ?? 0).clamp(0, 59),
  );
}

String _formatTime(TimeOfDay time) => '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

String _uomLabel(SupervisionSupplyUom uom) => switch (uom) {
      SupervisionSupplyUom.kg => 'supervision.union_camporees.uom_kg',
      SupervisionSupplyUom.l => 'supervision.union_camporees.uom_l',
      SupervisionSupplyUom.bag => 'supervision.union_camporees.uom_bag',
      SupervisionSupplyUom.unit => 'supervision.union_camporees.uom_unit',
      SupervisionSupplyUom.unknown => 'supervision.union_camporees.uom_unknown',
    }
        .tr();

/// Quiet text under a group.
class _Footnote extends StatelessWidget {
  const _Footnote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: SacFontSize.bodySmall,
          height: 1.35,
          color: context.sac.textTertiary,
        ),
      ),
    );
  }
}

/// Text link at the end of a group eyebrow, with a 44dp target.
class _EyebrowAction extends StatelessWidget {
  const _EyebrowAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SacPressable(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
        child: Align(
          alignment: Alignment.centerRight,
          widthFactor: 1,
          child: Text(
            label,
            style: TextStyle(
              fontSize: SacFontSize.titleSmall,
              fontWeight: FontWeight.w600,
              color: SacAccent.of(context).color,
            ),
          ),
        ),
      ),
    );
  }
}

/// Body shared by the two tabs: loading, error and the refreshable column.
class _TabBody<T> extends StatelessWidget {
  const _TabBody({
    required this.async,
    required this.onRefresh,
    required this.chips,
    required this.builder,
  });

  final AsyncValue<T> async;
  final Future<void> Function() onRefresh;
  final Widget? chips;
  final Widget Function(T value) builder;

  @override
  Widget build(BuildContext context) {
    final value = async.value;
    final Widget content;
    if (value == null && async.hasError) {
      content = Padding(
        padding: const EdgeInsets.only(top: 24),
        child: isForbiddenFailure(async.error!)
            ? const ForbiddenView()
            : SacErrorState(
                title: 'supervision.union_camporees.orders_error_title'.tr(),
                message: 'supervision.union_camporees.error_message'.tr(),
                onRetry: onRefresh,
              ),
      );
    } else if (value == null) {
      content = const Padding(
        padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: SacSkeletonList(
          itemCount: 5,
          leading: false,
          scrollable: false,
        ),
      );
    } else {
      content = builder(value);
    }
    return SupervisionScroll(
      onRefresh: onRefresh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [if (chips != null) chips!, content],
      ),
    );
  }
}

/// Sheet with a few fields in a scroll and, fixed at the bottom, one primary
/// «Guardar» with «Cancelar» under it. An inline error sits above them.
class _FormSheet extends StatelessWidget {
  const _FormSheet({
    required this.title,
    required this.children,
    required this.error,
    required this.busy,
    required this.onSave,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final String? error;
  final bool busy;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The header scrolls with the fields: at a large text scale only
            // the error and the buttons stay fixed.
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SacSheetHeader(title: title, subtitle: subtitle),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: children,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (error != null) SupervisionInlineError(message: error!),
            SupervisionSheetFooter(
              child: SupervisionStackedActions(
                primaryLabel: 'common.save'.tr(),
                primaryIcon: HugeIcons.strokeRoundedTick02,
                onPrimary: onSave,
                secondaryLabel: 'common.cancel'.tr(),
                secondaryDestructive: false,
                onSecondary: () => Navigator.of(context).pop(),
                isLoading: busy,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A labelled switch inside a form sheet.
class _SwitchLine extends StatelessWidget {
  const _SwitchLine({
    required this.label,
    required this.value,
    required this.onChanged,
    this.note,
  });

  final String label;
  final String? note;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return MergeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: SacFontSize.titleMedium,
                      fontWeight: FontWeight.w500,
                      color: c.text,
                    ),
                  ),
                  if (note != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      note!,
                      style: TextStyle(
                        fontSize: SacFontSize.bodyMedium,
                        height: 1.3,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Switch.adaptive(
              value: value,
              activeTrackColor: SacAccent.of(context).color,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Merchandise orders ──────────────────────────────────────────────────────

class _OrdersTab extends ConsumerStatefulWidget {
  const _OrdersTab({required this.camporeeId, required this.chips});

  final int camporeeId;
  final Widget? chips;

  @override
  ConsumerState<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends ConsumerState<_OrdersTab> {
  bool _saving = false;

  /// Position of the switch while its save is on the way, so it does not
  /// snap back to the old value until the server answers.
  bool? _enabledWhileSaving;

  Future<void> _refresh() async {
    final provider = supervisionCamporeeOrderConfigProvider(widget.camporeeId);
    ref.invalidate(provider);
    try {
      await ref.read(provider.future);
    } catch (_) {
      // The body renders the error.
    }
  }

  Future<void> _patch(SupervisionOrderSettingsPatch patch) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _enabledWhileSaving = patch.ordersEnabled;
    });
    final result = await ref
        .read(supervisionCamporeeOrderActionsProvider)
        .updateOrderSettings(widget.camporeeId, patch);
    if (result.ok) {
      // The action dropped the cached setup: wait for the fresh one so the
      // rows change once, to what the server kept.
      try {
        await ref.read(
          supervisionCamporeeOrderConfigProvider(widget.camporeeId).future,
        );
      } catch (_) {
        // The body renders the error.
      }
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _enabledWhileSaving = null;
    });
    SacSnackBar.show(
      context,
      result.ok
          ? 'supervision.union_camporees.saved_toast'.tr()
          : _saveError(result),
      isSuccess: result.ok,
      isError: !result.ok,
    );
  }

  /// Date, then time; null when either picker is dismissed.
  Future<DateTime?> _pickMoment(DateTime? current) async {
    final now = DateTime.now();
    final base = current?.toLocal() ?? now;
    final date = await showSacDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3, 12, 31),
      initialDate: base,
    );
    if (date == null || !mounted) return null;
    final time = await showTimePickerSheet(
      context,
      TimeOfDay(hour: base.hour, minute: base.minute),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _editMoment({
    required bool opening,
    required DateTime? current,
    required DateTime? other,
  }) async {
    // With a moment already set, the row can also take it away.
    if (current != null) {
      final clear = await showSacSheet<bool>(
        context: context,
        builder: (_) => _MomentActions(opening: opening),
      );
      if (clear == null || !mounted) return;
      if (clear) {
        await _patch(
          opening
              ? const SupervisionOrderSettingsPatch(clearOpensAt: true)
              : const SupervisionOrderSettingsPatch(clearDeadline: true),
        );
        return;
      }
    }
    final picked = await _pickMoment(current);
    if (picked == null || !mounted) return;
    final opens = opening ? picked : other?.toLocal();
    final deadline = opening ? other?.toLocal() : picked;
    if (opens != null && deadline != null && !opens.isBefore(deadline)) {
      SacSnackBar.show(
        context,
        'supervision.union_camporees.error_window_order'.tr(),
        isError: true,
      );
      return;
    }
    await _patch(
      opening
          ? SupervisionOrderSettingsPatch(opensAt: picked)
          : SupervisionOrderSettingsPatch(deadline: picked),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async =
        ref.watch(supervisionCamporeeOrderConfigProvider(widget.camporeeId));
    return _TabBody<SupervisionCamporeeOrderConfig>(
      async: async,
      onRefresh: _refresh,
      chips: widget.chips,
      builder: (config) => _buildConfig(context, config),
    );
  }

  Widget _buildConfig(
    BuildContext context,
    SupervisionCamporeeOrderConfig config,
  ) {
    final settings = config.settings;
    final none = 'supervision.union_camporees.no_date'.tr();
    String moment(DateTime? value) =>
        value == null ? none : supervisionDateTime(context, value.toLocal());
    final offered = config.products
        .where((p) => config.activeOfferingOf(p.productId) != null)
        .length;
    final enabled = _enabledWhileSaving ?? settings.ordersEnabled;
    final accent = SacAccent.of(context).color;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WindowPanel(
          enabled: settings.ordersEnabled,
          opensAt: settings.ordersOpensAt,
          deadline: settings.ordersDeadline,
        ),
        SacGroupedSection(
          label: 'supervision.union_camporees.window_title'.tr(),
          // A count of rows says nothing here.
          action: const SizedBox.shrink(),
          children: [
            SacListRow(
              leading: const SacListRowIcon(HugeIcons.strokeRoundedStore01),
              title: 'supervision.union_camporees.orders_enabled'.tr(),
              trailing: Switch.adaptive(
                value: enabled,
                activeTrackColor: accent,
                onChanged: _saving
                    ? null
                    : (value) => _patch(
                          SupervisionOrderSettingsPatch(ordersEnabled: value),
                        ),
              ),
            ),
            SacListRow(
              leading: const SacListRowIcon(HugeIcons.strokeRoundedCalendar03),
              title: 'supervision.union_camporees.opens_at'.tr(),
              trailing: _MomentValue(moment(settings.ordersOpensAt)),
              onTap: _saving
                  ? null
                  : () => _editMoment(
                        opening: true,
                        current: settings.ordersOpensAt,
                        other: settings.ordersDeadline,
                      ),
            ),
            SacListRow(
              leading: const SacListRowIcon(HugeIcons.strokeRoundedClock01),
              title: 'supervision.union_camporees.deadline'.tr(),
              trailing: _MomentValue(moment(settings.ordersDeadline)),
              onTap: _saving
                  ? null
                  : () => _editMoment(
                        opening: false,
                        current: settings.ordersDeadline,
                        other: settings.ordersOpensAt,
                      ),
            ),
          ],
        ),
        _Footnote('supervision.union_camporees.window_note'.tr()),
        if (config.products.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
            child: Text(
              'supervision.union_camporees.products_empty'.tr(),
              style: TextStyle(
                fontSize: SacFontSize.bodyMedium,
                height: 1.35,
                color: context.sac.textSecondary,
              ),
            ),
          )
        else ...[
          SacGroupedSection(
            label: 'supervision.union_camporees.products_title'.tr(),
            // «3 de 4»: on sale, out of the library.
            action: Text(
              'supervision.union_camporees.products_count'
                  .tr(args: ['$offered', '${config.products.length}']),
              style: TextStyle(
                fontSize: SacFontSize.labelSmall,
                fontWeight: FontWeight.w600,
                color: context.sac.textTertiary,
              ),
            ),
            children: [
              for (final product in config.products)
                _productRow(context, config, product),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: SacNotice(
              text: 'supervision.union_camporees.products_note'.tr(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _productRow(
    BuildContext context,
    SupervisionCamporeeOrderConfig config,
    CamporeeOrderProduct product,
  ) {
    final c = context.sac;
    final offering = config.activeOfferingOf(product.productId);
    final sizes = product.options.where((o) => o.active).length;
    final missingSizes = product.requiresOption && sizes == 0;

    final SupervisionStatusChip chip;
    if (missingSizes) {
      chip = SupervisionStatusChip(
        label: 'supervision.union_camporees.product_no_sizes'.tr(),
        icon: HugeIcons.strokeRoundedAlert02,
        tone: SacTone.warning,
      );
    } else if (offering == null) {
      chip = SupervisionStatusChip(
        label: 'supervision.union_camporees.product_not_offered'.tr(),
        icon: HugeIcons.strokeRoundedCancel01,
        tone: SacTone.muted,
      );
    } else {
      chip = SupervisionStatusChip(
        label: !product.requiresOption
            ? 'supervision.union_camporees.product_offered'.tr()
            : sizes == 1
                ? 'supervision.union_camporees.product_sizes_one'.tr()
                : 'supervision.union_camporees.product_sizes'
                    .tr(args: ['$sizes']),
        icon: HugeIcons.strokeRoundedTick02,
        tone: SacTone.success,
      );
    }

    return SacListRow(
      leading: SacListRowIcon(
        product.requiresOption
            ? HugeIcons.strokeRoundedShirt01
            : HugeIcons.strokeRoundedTag01,
        tone: offering == null ? SacTone.muted : SacTone.accent,
      ),
      title: product.title,
      subtitleWidget: Align(alignment: Alignment.centerLeft, child: chip),
      trailing: offering == null
          ? null
          : SupervisionTrailingFit(
              child: Text(
                SacMoney.fromCentavos(offering.priceCentavos),
                maxLines: 1,
                style: TextStyle(
                  fontSize: SacFontSize.titleMedium,
                  fontWeight: FontWeight.w700,
                  color: c.text,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
      onTap: () => showSacSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _OfferingSheet(
          camporeeId: widget.camporeeId,
          product: product,
          offering: offering,
          canOffer: !missingSizes,
        ),
      ),
    );
  }
}

/// Date and time at the end of a window row.
class _MomentValue extends StatelessWidget {
  const _MomentValue(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.4,
      ),
      child: Text(
        text,
        maxLines: 2,
        textAlign: TextAlign.end,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: SacFontSize.titleSmall,
          fontWeight: FontWeight.w500,
          color: context.sac.text,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// Where the order window stands right now, said in words on top of the tab.
class _WindowPanel extends StatelessWidget {
  const _WindowPanel({
    required this.enabled,
    required this.opensAt,
    required this.deadline,
  });

  final bool enabled;
  final DateTime? opensAt;
  final DateTime? deadline;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final SacStatusKind kind;
    final HugeIconData icon;
    final String title;
    String? message;
    if (!enabled) {
      kind = SacStatusKind.pending;
      icon = HugeIcons.strokeRoundedCancel01;
      title = 'supervision.union_camporees.orders_disabled'.tr();
      message = 'supervision.union_camporees.window_disabled_message'.tr();
    } else if (deadline != null && now.isAfter(deadline!)) {
      kind = SacStatusKind.pending;
      icon = HugeIcons.strokeRoundedLockKey;
      title = 'supervision.union_camporees.orders_closed'.tr();
      message = 'supervision.union_camporees.window_closed_message'.tr(
        args: [supervisionDateTime(context, deadline!.toLocal())],
      );
    } else if (opensAt != null && now.isBefore(opensAt!)) {
      kind = SacStatusKind.review;
      icon = HugeIcons.strokeRoundedCalendar03;
      title = 'supervision.union_camporees.orders_opens_on'
          .tr(args: [supervisionShortDate(context, opensAt!.toLocal())]);
    } else {
      kind = SacStatusKind.validated;
      icon = HugeIcons.strokeRoundedShoppingBag01;
      title = 'supervision.union_camporees.orders_open'.tr();
      message = deadline == null
          ? 'supervision.union_camporees.window_open_no_deadline'.tr()
          : 'supervision.union_camporees.window_open_until'.tr(
              args: [supervisionDateTime(context, deadline!.toLocal())],
            );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: SacStatePanel(
        style: SacStatusStyle.of(context, kind, label: title, icon: icon),
        title: title,
        message: message,
      ),
    );
  }
}

/// Change or remove a moment of the order window.
class _MomentActions extends StatelessWidget {
  const _MomentActions({required this.opening});

  final bool opening;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SacSheetHeader(
            title: (opening
                    ? 'supervision.union_camporees.opens_at'
                    : 'supervision.union_camporees.deadline')
                .tr(),
          ),
          SacListRow(
            leading: const SacListRowIcon(HugeIcons.strokeRoundedCalendar03),
            title: 'supervision.union_camporees.change_date'.tr(),
            showChevron: false,
            onTap: () => Navigator.of(context).pop(false),
          ),
          SacListRow(
            leading: const SacListRowIcon(
              HugeIcons.strokeRoundedCancel01,
              destructive: true,
            ),
            title: 'supervision.union_camporees.remove_date'.tr(),
            titleColor: context.sac.error,
            showChevron: false,
            onTap: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _OfferingSheet extends ConsumerStatefulWidget {
  const _OfferingSheet({
    required this.camporeeId,
    required this.product,
    required this.offering,
    required this.canOffer,
  });

  final int camporeeId;
  final CamporeeOrderProduct product;
  final CamporeeOrderOffering? offering;

  /// False when the product needs sizes and has none active.
  final bool canOffer;

  @override
  ConsumerState<_OfferingSheet> createState() => _OfferingSheetState();
}

class _OfferingSheetState extends ConsumerState<_OfferingSheet> {
  late bool _offered = widget.offering != null;
  late final _price = TextEditingController(
    text: widget.offering == null
        ? ''
        : _pesosText(widget.offering!.priceCentavos),
  );
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    int? centavos;
    if (_offered) {
      centavos = _parseCentavos(_price.text);
      if (centavos == null || centavos < 1) {
        setState(
          () => _error = 'supervision.union_camporees.error_price'.tr(),
        );
        return;
      }
    } else if (widget.offering == null) {
      // Nothing was on sale and nothing is: no request to make.
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result =
        await ref.read(supervisionCamporeeOrderActionsProvider).setOffering(
              widget.camporeeId,
              productId: widget.product.productId,
              offered: _offered,
              priceCentavos: centavos,
            );
    if (!mounted) return;
    if (result.ok) {
      SacSnackBar.show(
        context,
        'supervision.union_camporees.saved_toast'.tr(),
        isSuccess: true,
      );
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _busy = false;
      _error = _saveError(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final description = widget.product.description?.trim() ?? '';
    final activeSizes =
        widget.product.options.where((o) => o.active).toList(growable: false);
    // «5 tallas activas · Ch, M, G»: what the club will pick from.
    final sizesLine = activeSizes.isEmpty
        ? null
        : (activeSizes.length == 1
                ? 'supervision.union_camporees.sizes_active_one'
                : 'supervision.union_camporees.sizes_active')
            .tr(
            args: [
              if (activeSizes.length > 1) '${activeSizes.length}',
              activeSizes.map((o) => o.label).join(', '),
            ],
          );
    final subtitle = sizesLine ?? (description.isEmpty ? null : description);

    return _FormSheet(
      title: widget.product.title,
      subtitle: subtitle,
      error: _error,
      busy: _busy,
      onSave: _save,
      children: [
        Material(
          color: c.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            side: BorderSide(color: c.border),
          ),
          child: SacListRow(
            leading: const SacListRowIcon(HugeIcons.strokeRoundedStore01),
            title: 'supervision.union_camporees.offer_title'.tr(),
            subtitle: widget.canOffer
                ? 'supervision.union_camporees.offer_note'.tr()
                : 'supervision.union_camporees.offer_needs_sizes'.tr(),
            trailing: Switch.adaptive(
              value: _offered,
              activeTrackColor: SacAccent.of(context).color,
              // A product already on sale can always be taken off.
              onChanged: _busy || (!widget.canOffer && !_offered)
                  ? null
                  : (value) => setState(() {
                        _offered = value;
                        _error = null;
                      }),
            ),
          ),
        ),
        if (_offered) ...[
          const SizedBox(height: 16),
          SacTextField(
            controller: _price,
            label: 'supervision.union_camporees.price_label'.tr(),
            prefixText: r'$ ',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: _priceFormatters,
            enabled: !_busy,
          ),
        ],
      ],
    );
  }
}

// ── Supplies ────────────────────────────────────────────────────────────────

class _SuppliesTab extends ConsumerStatefulWidget {
  const _SuppliesTab({required this.camporeeId, required this.chips});

  final int camporeeId;
  final Widget? chips;

  @override
  ConsumerState<_SuppliesTab> createState() => _SuppliesTabState();
}

class _SuppliesTabState extends ConsumerState<_SuppliesTab> {
  bool _saving = false;

  Future<void> _refresh() async {
    final provider = supervisionSupplyCatalogProvider(widget.camporeeId);
    ref.invalidate(provider);
    try {
      await ref.read(provider.future);
    } catch (_) {
      // The body renders the error.
    }
  }

  Future<void> _editCutoff(String current) async {
    if (_saving) return;
    final picked = await showTimePickerSheet(context, _parseTime(current));
    if (picked == null || !mounted) return;
    final value = _formatTime(picked);
    if (value == current) return;
    setState(() => _saving = true);
    final result = await ref
        .read(supervisionCamporeeOrderActionsProvider)
        .updateSupplyCutoff(widget.camporeeId, value);
    if (!mounted) return;
    setState(() => _saving = false);
    SacSnackBar.show(
      context,
      result.ok
          ? 'supervision.union_camporees.saved_toast'.tr()
          : _saveError(result),
      isSuccess: result.ok,
      isError: !result.ok,
    );
  }

  void _openSlot(SupervisionSupplySlot? slot) {
    showSacSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SlotSheet(camporeeId: widget.camporeeId, slot: slot),
    );
  }

  void _openProduct(SupervisionSupplyProduct? product) {
    showSacSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          _SupplyProductSheet(camporeeId: widget.camporeeId, product: product),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async =
        ref.watch(supervisionSupplyCatalogProvider(widget.camporeeId));
    return _TabBody<SupervisionSupplyCatalog>(
      async: async,
      onRefresh: _refresh,
      chips: widget.chips,
      builder: (catalog) => _buildCatalog(context, catalog),
    );
  }

  Widget _buildCatalog(BuildContext context, SupervisionSupplyCatalog catalog) {
    final inactive = 'supervision.union_camporees.inactive'.tr();
    final add = 'supervision.union_camporees.add'.tr();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SacGroupedSection(
          label: 'supervision.union_camporees.cutoff_title'.tr(),
          // A count of rows says nothing here.
          action: const SizedBox.shrink(),
          children: [
            SacListRow(
              leading: const SacListRowIcon(HugeIcons.strokeRoundedLockKey),
              title: 'supervision.union_camporees.cutoff'.tr(),
              subtitle: catalog.timezone.trim().isEmpty
                  ? null
                  : 'supervision.union_camporees.cutoff_timezone'
                      .tr(args: [supervisionZoneLabel(catalog.timezone)]),
              trailing: SupervisionTrailingFit(
                child: SupervisionRowValue(catalog.cutoffTime),
              ),
              onTap: _saving ? null : () => _editCutoff(catalog.cutoffTime),
            ),
          ],
        ),
        _Footnote('supervision.union_camporees.cutoff_note'.tr()),
        SacGroupedSection(
          label: 'supervision.union_camporees.slots_title'.tr(),
          action: _EyebrowAction(label: add, onTap: () => _openSlot(null)),
          children: [
            if (catalog.slots.isEmpty)
              SupervisionPlainRow(
                title: 'supervision.union_camporees.slots_empty'.tr(),
              ),
            for (final slot in catalog.slots)
              _Dimmed(
                dimmed: !slot.active,
                child: SacListRow(
                  leading: SacListRowIcon(
                    HugeIcons.strokeRoundedClock01,
                    tone: slot.active ? SacTone.accent : SacTone.muted,
                  ),
                  title: slot.label,
                  subtitle: slot.active ? null : inactive,
                  trailing: SupervisionTrailingFit(
                    child: SupervisionRowValue(slot.deliverTime),
                  ),
                  onTap: () => _openSlot(slot),
                ),
              ),
          ],
        ),
        SacGroupedSection(
          label: 'supervision.union_camporees.supply_products_title'.tr(),
          action: _EyebrowAction(label: add, onTap: () => _openProduct(null)),
          children: [
            if (catalog.products.isEmpty)
              SupervisionPlainRow(
                title: 'supervision.union_camporees.supply_products_empty'.tr(),
              ),
            for (final product in catalog.products)
              _Dimmed(
                dimmed: !product.active,
                child: SacListRow(
                  leading: SacListRowIcon(
                    HugeIcons.strokeRoundedPackage01,
                    tone: product.active ? SacTone.accent : SacTone.muted,
                  ),
                  title: product.name,
                  subtitle: [
                    'supervision.union_camporees.per_uom'
                        .tr(args: [_uomLabel(product.uom)]),
                    if (!product.active) inactive,
                  ].join(' · '),
                  trailing: SupervisionTrailingFit(
                    child: SupervisionRowValue(
                      SacMoney.fromCentavos(product.unitCostCentavos),
                    ),
                  ),
                  onTap: () => _openProduct(product),
                ),
              ),
          ],
        ),
        _Footnote('supervision.union_camporees.supply_note'.tr()),
      ],
    );
  }
}

/// Quiets an inactive row without taking away its tap.
class _Dimmed extends StatelessWidget {
  const _Dimmed({required this.dimmed, required this.child});

  final bool dimmed;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      dimmed ? Opacity(opacity: 0.6, child: child) : child;
}

class _SlotSheet extends ConsumerStatefulWidget {
  const _SlotSheet({required this.camporeeId, required this.slot});

  final int camporeeId;

  /// Null creates a delivery time.
  final SupervisionSupplySlot? slot;

  @override
  ConsumerState<_SlotSheet> createState() => _SlotSheetState();
}

class _SlotSheetState extends ConsumerState<_SlotSheet> {
  late final _label = TextEditingController(text: widget.slot?.label ?? '');
  late String _time = widget.slot?.deliverTime ?? '12:00';
  late bool _active = widget.slot?.active ?? true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePickerSheet(context, _parseTime(_time));
    if (picked == null || !mounted) return;
    setState(() => _time = _formatTime(picked));
  }

  Future<void> _save() async {
    final label = _label.text.trim();
    if (label.isEmpty) {
      setState(
        () => _error = 'supervision.union_camporees.error_label'.tr(),
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final slot = widget.slot;
    final result =
        await ref.read(supervisionCamporeeOrderActionsProvider).saveSupplySlot(
              widget.camporeeId,
              slotId: slot?.id,
              label: label,
              deliverTime: _time,
              active: slot == null ? null : _active,
            );
    if (!mounted) return;
    if (result.ok) {
      SacSnackBar.show(
        context,
        'supervision.union_camporees.saved_toast'.tr(),
        isSuccess: true,
      );
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _busy = false;
      _error = _saveError(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return _FormSheet(
      title: (widget.slot == null
              ? 'supervision.union_camporees.slot_new'
              : 'supervision.union_camporees.slot_edit')
          .tr(),
      error: _error,
      busy: _busy,
      onSave: _save,
      children: [
        SacTextField(
          controller: _label,
          label: 'supervision.union_camporees.slot_label'.tr(),
          hint: 'supervision.union_camporees.slot_label_hint'.tr(),
          maxLength: _kSlotLabelMax,
          textCapitalization: TextCapitalization.sentences,
          enabled: !_busy,
        ),
        const SizedBox(height: 12),
        Material(
          color: c.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            side: BorderSide(color: c.border),
          ),
          child: SupervisionPlainRow(
            title: 'supervision.union_camporees.slot_time'.tr(),
            trailing: SupervisionRowValue(_time),
            onTap: _busy ? null : _pickTime,
          ),
        ),
        if (widget.slot != null) ...[
          const SizedBox(height: 12),
          _SwitchLine(
            label: 'supervision.union_camporees.active_switch'.tr(),
            note: 'supervision.union_camporees.slot_active_note'.tr(),
            value: _active,
            onChanged:
                _busy ? null : (value) => setState(() => _active = value),
          ),
        ],
      ],
    );
  }
}

class _SupplyProductSheet extends ConsumerStatefulWidget {
  const _SupplyProductSheet({required this.camporeeId, required this.product});

  final int camporeeId;

  /// Null creates a supply product.
  final SupervisionSupplyProduct? product;

  @override
  ConsumerState<_SupplyProductSheet> createState() =>
      _SupplyProductSheetState();
}

class _SupplyProductSheetState extends ConsumerState<_SupplyProductSheet> {
  static const _uoms = [
    SupervisionSupplyUom.kg,
    SupervisionSupplyUom.l,
    SupervisionSupplyUom.bag,
    SupervisionSupplyUom.unit,
  ];

  late final _name = TextEditingController(text: widget.product?.name ?? '');
  late final _price = TextEditingController(
    text: widget.product == null
        ? ''
        : _pesosText(widget.product!.unitCostCentavos),
  );
  late SupervisionSupplyUom? _uom = _uoms.contains(widget.product?.uom)
      ? widget.product!.uom
      : (widget.product == null ? SupervisionSupplyUom.unit : null);
  late bool _active = widget.product?.active ?? true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final centavos = _parseCentavos(_price.text);
    final uom = _uom;
    final String? problem;
    if (name.isEmpty) {
      problem = 'supervision.union_camporees.error_name';
    } else if (uom == null) {
      problem = 'supervision.union_camporees.error_uom';
    } else if (centavos == null) {
      problem = 'supervision.union_camporees.error_price';
    } else {
      problem = null;
    }
    if (problem != null) {
      setState(() => _error = problem!.tr());
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final product = widget.product;
    // An unchanged price is not sent: the server locks it once a plan is in.
    final priceChanged =
        product == null || product.unitCostCentavos != centavos;
    final result = await ref
        .read(supervisionCamporeeOrderActionsProvider)
        .saveSupplyProduct(
          widget.camporeeId,
          productId: product?.id,
          name: name,
          uom: uom,
          unitCostCentavos: priceChanged ? centavos : null,
          active: product == null ? null : _active,
        );
    if (!mounted) return;
    if (result.ok) {
      SacSnackBar.show(
        context,
        'supervision.union_camporees.saved_toast'.tr(),
        isSuccess: true,
      );
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _busy = false;
      _error = _saveError(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    return _FormSheet(
      title: (widget.product == null
              ? 'supervision.union_camporees.supply_product_new'
              : 'supervision.union_camporees.supply_product_edit')
          .tr(),
      error: _error,
      busy: _busy,
      onSave: _save,
      children: [
        SacTextField(
          controller: _name,
          label: 'supervision.union_camporees.supply_product_name'.tr(),
          maxLength: _kProductNameMax,
          textCapitalization: TextCapitalization.sentences,
          enabled: !_busy,
        ),
        const SizedBox(height: 12),
        SacDropdownField<SupervisionSupplyUom>(
          label: 'supervision.union_camporees.supply_product_uom'.tr(),
          value: _uom,
          enabled: !_busy,
          items: [
            for (final uom in _uoms)
              DropdownMenuItem(value: uom, child: Text(_uomLabel(uom))),
          ],
          onChanged: (value) => setState(() => _uom = value),
        ),
        const SizedBox(height: 12),
        SacTextField(
          controller: _price,
          label: 'supervision.union_camporees.supply_product_price'.tr(),
          prefixText: r'$ ',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: _priceFormatters,
          enabled: !_busy,
        ),
        if (widget.product != null) ...[
          const SizedBox(height: 12),
          _SwitchLine(
            label: 'supervision.union_camporees.active_switch'.tr(),
            note: 'supervision.union_camporees.supply_product_active_note'.tr(),
            value: _active,
            onChanged:
                _busy ? null : (value) => setState(() => _active = value),
          ),
        ],
      ],
    );
  }
}
