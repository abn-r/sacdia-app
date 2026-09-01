import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/date_formatter.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/widgets/sac_back_button.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';
import 'package:sacdia_app/core/widgets/sac_text_field.dart';
import 'package:sacdia_app/features/camporee_orders/domain/entities/camporee_order.dart';
import 'package:sacdia_app/features/camporee_supplies/domain/entities/camporee_supply_plan.dart';
import 'package:sacdia_app/features/camporee_supplies/domain/utils/camporee_supply_plan_groups.dart';
import 'package:sacdia_app/features/camporee_supplies/presentation/providers/camporee_supplies_providers.dart';
import 'package:sacdia_app/features/camporees/presentation/providers/camporees_providers.dart';
import 'package:sacdia_app/features/camporees/presentation/widgets/camporee_participant_access_gate.dart';

class CamporeeSuppliesCta extends ConsumerWidget {
  final int camporeeId;
  final CamporeeKind camporeeType;
  final bool embedded;

  const CamporeeSuppliesCta({
    super.key,
    required this.camporeeId,
    this.camporeeType = CamporeeKind.local,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registrationAsync =
        ref.watch(camporeeSectionRegistrationProvider(camporeeId));
    if (!camporeeParticipantsAreEnabled(registrationAsync)) {
      return const SizedBox.shrink();
    }

    final button = SacButton(
      key: const Key('camporee-supplies-cta'),
      text: 'camporee_supplies.cta.label'.tr(),
      icon: HugeIcons.strokeRoundedInvoice01,
      variant: embedded ? SacButtonVariant.outline : SacButtonVariant.primary,
      onPressed: () => context.push(
        RouteNames.camporeeSuppliesPath(
          camporeeId,
          type: camporeeType == CamporeeKind.union ? 'union' : 'local',
        ),
      ),
      labelMaxLines: 2,
      labelOverflow: TextOverflow.visible,
      fullWidth: true,
    );

    if (embedded) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: button,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: button,
    );
  }
}

class CamporeeSupplyPlanView extends ConsumerStatefulWidget {
  final int camporeeId;
  final CamporeeKind camporeeType;

  const CamporeeSupplyPlanView({
    super.key,
    required this.camporeeId,
    this.camporeeType = CamporeeKind.local,
  });

  @override
  ConsumerState<CamporeeSupplyPlanView> createState() =>
      _CamporeeSupplyPlanViewState();
}

class _CamporeeSupplyPlanViewState
    extends ConsumerState<CamporeeSupplyPlanView> {
  String? _date;
  String? _slotId;
  String? _productId;
  List<CamporeeSupplyLineInput> _draftLines = [];

  CamporeeSuppliesScope get _scope => CamporeeSuppliesScope(
        camporeeId: widget.camporeeId,
        type: widget.camporeeType,
      );

  @override
  Widget build(BuildContext context) {
    final envelopeAsync = ref.watch(camporeeSupplyPlanProvider(_scope));
    final c = context.sac;

    return Scaffold(
      backgroundColor: c.surfaceVariant,
      appBar: AppBar(
        backgroundColor: c.surfaceVariant,
        foregroundColor: c.text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: SacBackButton(color: c.text),
        title: Text(
          'camporee_supplies.plan.title'.tr(),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: c.text,
              ),
        ),
      ),
      body: envelopeAsync.when(
        loading: () => const SacLoading(),
        error: (error, _) => Center(
          child: Text(camporeeSuppliesErrorMessage(error)),
        ),
        data: (loaded) {
          final plan = loaded.plan;
          if (_draftLines.isEmpty && plan != null && plan.isDraft) {
            _draftLines = plan.lines.map((line) => line.toInput()).toList();
          }
          final dates = _datesBetween(
            loaded.catalog.startDate,
            loaded.catalog.endDate,
          );
          _date ??= dates.isEmpty ? null : dates.first;
          _slotId ??= loaded.catalog.slots.isEmpty
              ? null
              : loaded.catalog.slots.first.slotId;
          _productId ??= loaded.catalog.products.isEmpty
              ? null
              : loaded.catalog.products.first.productId;

          final submitted = plan?.isSubmitted == true;
          final lines = submitted
              ? plan!.lines.map((line) => line.toInput()).toList()
              : _draftLines;
          final groups = groupCamporeeSupplyLines(
            dates: dates,
            slots: loaded.catalog.slots,
            lines: lines,
          );
          final estimated = estimateCamporeeSupplyTotal(
            lines: lines,
            products: loaded.catalog.products,
          );
          final dueCentavos = submitted ? plan!.netCentavos : estimated;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _CutoffCaption(time: loaded.catalog.cutoff),
              const SizedBox(height: 16),
              _PaymentCard(
                plan: plan,
                submitted: submitted,
                dueCentavos: dueCentavos,
              ),
              if (!loaded.catalog.isReady) ...[
                const SizedBox(height: 20),
                Text(
                  'camporee_supplies.plan.catalog_empty'.tr(),
                  style: TextStyle(color: c.textSecondary),
                ),
              ] else ...[
                const SizedBox(height: 12),
                _AddSupplyButton(
                  key: const Key('camporee-supply-add'),
                  onPressed: () => _openAddSheet(loaded),
                ),
                const SizedBox(height: 16),
                if (lines.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'camporee_supplies.plan.empty'.tr(),
                      style: TextStyle(color: c.textSecondary),
                    ),
                  ),
                for (var index = 0; index < groups.length; index++) ...[
                  _DayCard(
                    group: groups[index],
                    catalog: loaded.catalog,
                    locale: context.locale.languageCode,
                    animationDelay: SacMotion.stagger * index,
                    onRemove: submitted
                        ? null
                        : (line) => setState(
                              () => _draftLines.removeWhere(
                                (row) =>
                                    row.date == line.date &&
                                    row.slotId == line.slotId &&
                                    row.productId == line.productId,
                              ),
                            ),
                  ),
                  if (index < groups.length - 1) const SizedBox(height: 12),
                ],
                if (!submitted) ...[
                  const SizedBox(height: 20),
                  SacButton.outline(
                    text: 'camporee_supplies.plan.save'.tr(),
                    onPressed: () => _save(),
                  ),
                  const SizedBox(height: 8),
                  SacButton.primary(
                    text: 'camporee_supplies.plan.submit'.tr(),
                    isEnabled: lines.isNotEmpty,
                    onPressed: () => _submit(),
                  ),
                ],
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _openAddSheet(CamporeeSupplyPlanEnvelope envelope) async {
    final dates = _datesBetween(
      envelope.catalog.startDate,
      envelope.catalog.endDate,
    );
    final submitted = envelope.plan?.isSubmitted == true;
    await showSacSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _AddSupplySheet(
          dates: dates,
          catalog: envelope.catalog,
          date: _date ?? (dates.isEmpty ? null : dates.first),
          slotId: _slotId ??
              (envelope.catalog.slots.isEmpty
                  ? null
                  : envelope.catalog.slots.first.slotId),
          productId: _productId ??
              (envelope.catalog.products.isEmpty
                  ? null
                  : envelope.catalog.products.first.productId),
          onAdd: (input) async {
            setState(() {
              _date = input.date;
              _slotId = input.slotId;
              _productId = input.productId;
            });
            await _addLine(submitted, input);
          },
        );
      },
    );
  }

  Future<void> _addLine(
    bool submitted,
    CamporeeSupplyLineInput input,
  ) async {
    if (input.qty <= 0) {
      _toast('camporee_supplies.errors.qty_invalid'.tr());
      return;
    }
    final repo = ref.read(camporeeSuppliesRepositoryProvider);
    if (submitted) {
      final result = await repo.adjustLine(
        camporeeId: widget.camporeeId,
        camporeeType: widget.camporeeType,
        line: input,
      );
      result.fold(
        (failure) => _toast(failure.message),
        (_) {
          ref.invalidate(camporeeSupplyPlanProvider(_scope));
          _toast('camporee_supplies.plan.adjusted'.tr());
        },
      );
      return;
    }
    setState(() {
      _draftLines.removeWhere(
        (row) =>
            row.date == input.date &&
            row.slotId == input.slotId &&
            row.productId == input.productId,
      );
      _draftLines.add(input);
    });
  }

  Future<void> _save() async {
    final result =
        await ref.read(camporeeSuppliesRepositoryProvider).replaceDraft(
              camporeeId: widget.camporeeId,
              camporeeType: widget.camporeeType,
              lines: _draftLines,
            );
    result.fold(
      (failure) => _toast(failure.message),
      (_) {
        ref.invalidate(camporeeSupplyPlanProvider(_scope));
        _toast('camporee_supplies.plan.saved'.tr());
      },
    );
  }

  Future<void> _submit() async {
    final saved =
        await ref.read(camporeeSuppliesRepositoryProvider).replaceDraft(
              camporeeId: widget.camporeeId,
              camporeeType: widget.camporeeType,
              lines: _draftLines,
            );
    final savedOk = saved.fold((failure) {
      _toast(failure.message);
      return false;
    }, (_) => true);
    if (!savedOk) return;
    final result = await ref.read(camporeeSuppliesRepositoryProvider).submit(
          camporeeId: widget.camporeeId,
          camporeeType: widget.camporeeType,
        );
    result.fold(
      (failure) => _toast(failure.message),
      (_) {
        ref.invalidate(camporeeSupplyPlanProvider(_scope));
        _toast('camporee_supplies.plan.submitted'.tr());
      },
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _CutoffCaption extends StatelessWidget {
  final String time;

  const _CutoffCaption({required this.time});

  @override
  Widget build(BuildContext context) {
    final label = 'camporee_supplies.plan.cutoff'.tr(
      namedArgs: {'time': time},
    );

    return Align(
      alignment: Alignment.center,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.accentLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedClock01,
                size: 14,
                color: AppColors.accentDark,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.accentDark,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final CamporeeSupplyPlan? plan;
  final bool submitted;
  final int dueCentavos;

  const _PaymentCard({
    required this.plan,
    required this.submitted,
    required this.dueCentavos,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final payments = plan?.payments ?? const <CamporeeSupplyPayment>[];
    final amountLabel = submitted
        ? 'camporee_supplies.plan.payment_due'.tr()
        : 'camporee_supplies.plan.payment_estimated'.tr();

    return SacCard(
      key: const Key('camporee-supply-payment'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'camporee_supplies.plan.payment_title'.tr(),
            style: TextStyle(
              color: c.textTertiary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            amountLabel,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatPesos(dueCentavos),
            style: TextStyle(
              color: c.text,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              height: 1.1,
            ),
          ),
          if (!submitted) ...[
            const SizedBox(height: 8),
            Text(
              'camporee_supplies.plan.payment_pending_folio'.tr(),
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
          if (payments.isNotEmpty) ...[
            const SizedBox(height: 14),
            Divider(height: 1, color: c.divider),
            const SizedBox(height: 8),
            for (final payment in payments)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            payment.folioReference,
                            style: TextStyle(
                              color: c.text,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_paymentKindLabel(payment.kind)} · ${_paymentStatusLabel(payment.status)}',
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _formatPesos(payment.totalCentavos),
                      style: TextStyle(
                        color: c.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _AddSupplyButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _AddSupplyButton({super.key, required this.onPressed});

  @override
  State<_AddSupplyButton> createState() => _AddSupplyButtonState();
}

class _AddSupplyButtonState extends State<_AddSupplyButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final reduce = SacMotion.reduceMotionOf(context);
    final label = 'camporee_supplies.plan.add_item'.tr();
    final hint = 'camporee_supplies.plan.add_hint'.tr();

    return Semantics(
      button: true,
      label: label,
      hint: hint,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) {
          HapticFeedback.lightImpact();
          _setPressed(true);
        },
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: (!reduce && _pressed) ? SacMotion.pressScale : 1,
          duration: SacMotion.press,
          curve: SacMotion.easeOut,
          child: ExcludeSemantics(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.28),
                  ),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedAdd01,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              hint,
                              style: TextStyle(
                                color: c.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedArrowRight01,
                        size: 18,
                        color: c.textTertiary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  final CamporeeSupplyDayBucket group;
  final CamporeeSupplyCatalog catalog;
  final String locale;
  final Duration animationDelay;
  final ValueChanged<CamporeeSupplyLineInput>? onRemove;

  const _DayCard({
    required this.group,
    required this.catalog,
    required this.locale,
    required this.animationDelay,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final parsed = _parseIsoDate(group.date);
    final dateLabel = SacDateFormatter.formatCalendar(
      parsed,
      'EEE d MMM',
      locale: locale,
    );

    return SacCard(
      key: Key('camporee-supply-day-${group.date}'),
      animate: true,
      animationDelay: animationDelay,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'camporee_supplies.plan.day_index'.tr(
                    namedArgs: {'day': '${group.dayNumber}'},
                  ),
                  style: TextStyle(
                    color: c.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                if (dateLabel.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    dateLabel,
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (group.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'camporee_supplies.plan.day_empty'.tr(),
                style: TextStyle(color: c.textSecondary, fontSize: 13),
              ),
            )
          else
            for (var slotIndex = 0;
                slotIndex < group.slots.length;
                slotIndex++) ...[
              if (slotIndex > 0) Divider(height: 1, color: c.divider),
              _SlotBlock(
                bucket: group.slots[slotIndex],
                catalog: catalog,
                date: group.date,
                onRemove: onRemove,
              ),
            ],
        ],
      ),
    );
  }
}

class _SlotBlock extends StatelessWidget {
  final CamporeeSupplySlotBucket bucket;
  final CamporeeSupplyCatalog catalog;
  final String date;
  final ValueChanged<CamporeeSupplyLineInput>? onRemove;

  const _SlotBlock({
    required this.bucket,
    required this.catalog,
    required this.date,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final time = bucket.slot.deliverTime.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
          child: Text(
            time.isEmpty
                ? bucket.slot.label.toUpperCase()
                : '${bucket.slot.label} · $time'.toUpperCase(),
            key: Key('camporee-supply-slot-$date-${bucket.slot.slotId}'),
            style: TextStyle(
              color: c.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              height: 1.2,
            ),
          ),
        ),
        for (var i = 0; i < bucket.lines.length; i++) ...[
          if (i > 0) Divider(height: 1, color: c.divider),
          _LineTile(
            line: bucket.lines[i],
            catalog: catalog,
            onRemove:
                onRemove == null ? null : () => onRemove!(bucket.lines[i]),
          ),
        ],
      ],
    );
  }
}

class _AddSupplySheet extends StatefulWidget {
  final List<String> dates;
  final CamporeeSupplyCatalog catalog;
  final String? date;
  final String? slotId;
  final String? productId;
  final Future<void> Function(CamporeeSupplyLineInput input) onAdd;

  const _AddSupplySheet({
    required this.dates,
    required this.catalog,
    required this.onAdd,
    this.date,
    this.slotId,
    this.productId,
  });

  @override
  State<_AddSupplySheet> createState() => _AddSupplySheetState();
}

class _AddSupplySheetState extends State<_AddSupplySheet> {
  late String? _date;
  late String? _slotId;
  late String? _productId;
  late final TextEditingController _qtyController;

  @override
  void initState() {
    super.initState();
    _date = widget.date;
    _slotId = widget.slotId;
    _productId = widget.productId;
    _qtyController = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final qty = double.tryParse(_qtyController.text.replaceAll(',', '.'));
    if (_date == null || _slotId == null || _productId == null) return;
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('camporee_supplies.errors.qty_invalid'.tr())),
      );
      return;
    }
    HapticFeedback.selectionClick();
    await widget.onAdd(
      CamporeeSupplyLineInput(
        date: _date!,
        slotId: _slotId!,
        productId: _productId!,
        qty: qty,
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.92,
          ),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppTheme.radiusLG),
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.border,
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'camporee_supplies.plan.add_item'.tr(),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 16),
                _AddRow(
                  dates: widget.dates,
                  catalog: widget.catalog,
                  date: _date,
                  slotId: _slotId,
                  productId: _productId,
                  qtyController: _qtyController,
                  onDate: (value) => setState(() => _date = value),
                  onSlot: (value) => setState(() => _slotId = value),
                  onProduct: (value) => setState(() => _productId = value),
                  onAdd: () {
                    _submit();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddRow extends StatelessWidget {
  final List<String> dates;
  final CamporeeSupplyCatalog catalog;
  final String? date;
  final String? slotId;
  final String? productId;
  final TextEditingController qtyController;
  final ValueChanged<String?> onDate;
  final ValueChanged<String?> onSlot;
  final ValueChanged<String?> onProduct;
  final VoidCallback onAdd;

  const _AddRow({
    required this.dates,
    required this.catalog,
    required this.date,
    required this.slotId,
    required this.productId,
    required this.qtyController,
    required this.onDate,
    required this.onSlot,
    required this.onProduct,
    required this.onAdd,
  });

  CamporeeSupplySlot? get _slot {
    if (slotId == null) return null;
    for (final slot in catalog.slots) {
      if (slot.slotId == slotId) return slot;
    }
    return null;
  }

  CamporeeSupplyProduct? get _product {
    if (productId == null) return null;
    for (final product in catalog.products) {
      if (product.productId == productId) return product;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final slot = _slot;
    final product = _product;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SupplySelectField(
          fieldKey: const Key('camporee-supply-field-date'),
          label: 'camporee_supplies.plan.date'.tr(),
          value: date == null ? '' : _formatSupplyDate(context, date!),
          prefixIcon: HugeIcons.strokeRoundedCalendar01,
          onTap: () async {
            final picked = await _pickSupplyOption(
              context: context,
              title: 'camporee_supplies.plan.date'.tr(),
              options: [
                for (final item in dates)
                  (item, _formatSupplyDate(context, item)),
              ],
              selected: date,
            );
            if (picked != null) onDate(picked);
          },
        ),
        const SizedBox(height: 14),
        _SupplySelectField(
          fieldKey: const Key('camporee-supply-field-slot'),
          label: 'camporee_supplies.plan.slot'.tr(),
          value: slot == null ? '' : '${slot.label} (${slot.deliverTime})',
          prefixIcon: HugeIcons.strokeRoundedClock01,
          onTap: () async {
            final picked = await _pickSupplyOption(
              context: context,
              title: 'camporee_supplies.plan.slot'.tr(),
              options: [
                for (final item in catalog.slots)
                  (item.slotId, '${item.label} (${item.deliverTime})'),
              ],
              selected: slotId,
            );
            if (picked != null) onSlot(picked);
          },
        ),
        const SizedBox(height: 14),
        _SupplySelectField(
          fieldKey: const Key('camporee-supply-field-product'),
          label: 'camporee_supplies.plan.product'.tr(),
          value: product == null
              ? ''
              : '${product.name} · ${_formatPesos(product.unitCostCentavos)}/${product.uom}',
          prefixIcon: HugeIcons.strokeRoundedInvoice01,
          onTap: () async {
            final picked = await _pickSupplyOption(
              context: context,
              title: 'camporee_supplies.plan.product'.tr(),
              options: [
                for (final item in catalog.products)
                  (
                    item.productId,
                    '${item.name} · ${_formatPesos(item.unitCostCentavos)}/${item.uom}',
                  ),
              ],
              selected: productId,
            );
            if (picked != null) onProduct(picked);
          },
        ),
        const SizedBox(height: 14),
        SacTextField(
          key: const Key('camporee-supply-field-qty'),
          controller: qtyController,
          label: 'camporee_supplies.plan.qty'.tr(),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          suffixText: product?.uom,
        ),
        const SizedBox(height: 16),
        SacButton.primary(
          key: const Key('camporee-supply-add-confirm'),
          text: 'camporee_supplies.plan.add'.tr(),
          onPressed: onAdd,
        ),
      ],
    );
  }
}

class _SupplySelectField extends StatefulWidget {
  final Key fieldKey;
  final String label;
  final String value;
  final HugeIconData prefixIcon;
  final VoidCallback onTap;

  const _SupplySelectField({
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.prefixIcon,
    required this.onTap,
  });

  @override
  State<_SupplySelectField> createState() => _SupplySelectFieldState();
}

class _SupplySelectFieldState extends State<_SupplySelectField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _SupplySelectField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return SacTextField(
      key: widget.fieldKey,
      controller: _controller,
      label: widget.label,
      prefixIcon: widget.prefixIcon,
      readOnly: true,
      onTap: widget.onTap,
      suffix: IgnorePointer(
        child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowDown01,
            size: 20,
            color: c.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _LineTile extends StatelessWidget {
  final CamporeeSupplyLineInput line;
  final CamporeeSupplyCatalog catalog;
  final VoidCallback? onRemove;

  const _LineTile({
    required this.line,
    required this.catalog,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final product =
        catalog.products.where((item) => item.productId == line.productId);
    final uom = product.isEmpty ? '' : product.first.uom;
    final name = product.isEmpty ? line.productId : product.first.name;
    final qty = '${_formatQty(line.qty)} $uom'.trim();
    final icon = _supplyProductIcon(name, uom);
    final color = _supplyProductColor(context, name, uom);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      child: Row(
        children: [
          _SupplyIcon(
            key: Key(
              'camporee-supply-icon-${line.date}-${line.slotId}-${line.productId}',
            ),
            icon: icon,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: c.text,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            qty,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (onRemove != null)
            Semantics(
              button: true,
              label: 'common.delete'.tr(),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onRemove,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedCancel01,
                      size: 18,
                      color: c.textTertiary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SupplyIcon extends StatelessWidget {
  final HugeIconData icon;
  final Color color;

  const _SupplyIcon({
    super.key,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: HugeIcon(icon: icon, size: 16, color: color),
      ),
    );
  }
}

String _foldSupplyName(String raw) {
  const map = {
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
  };
  final buffer = StringBuffer();
  for (final rune in raw.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    buffer.write(map[char] ?? char);
  }
  return buffer.toString();
}

HugeIconData _supplyProductIcon(String name, String uom) {
  final folded = _foldSupplyName(name);
  if (folded.contains('hielo') || folded.contains('ice')) {
    return HugeIcons.strokeRoundedIceCubes;
  }
  if (folded.contains('leche') || folded.contains('milk')) {
    return HugeIcons.strokeRoundedMilkBottle;
  }
  if (folded.contains('agua') ||
      folded.contains('garraf') ||
      folded.contains('water')) {
    return HugeIcons.strokeRoundedDroplet;
  }
  if (folded.contains('tortilla') ||
      folded.contains('pan') ||
      folded.contains('bread')) {
    return HugeIcons.strokeRoundedBread01;
  }
  switch (uom.toUpperCase()) {
    case 'L':
      return HugeIcons.strokeRoundedDroplet;
    case 'KG':
      return HugeIcons.strokeRoundedPackage01;
    case 'BAG':
      return HugeIcons.strokeRoundedShoppingBag01;
    default:
      return HugeIcons.strokeRoundedPackage;
  }
}

Color _supplyProductColor(BuildContext context, String name, String uom) {
  final folded = _foldSupplyName(name);
  if (folded.contains('hielo') || folded.contains('ice')) {
    return context.sac.info;
  }
  if (folded.contains('leche') || folded.contains('milk')) {
    return context.sac.warning;
  }
  if (folded.contains('agua') ||
      folded.contains('garraf') ||
      folded.contains('water')) {
    return AppColors.secondary;
  }
  if (folded.contains('tortilla') ||
      folded.contains('pan') ||
      folded.contains('bread')) {
    return context.sac.warning;
  }
  return AppColors.primary;
}

Future<String?> _pickSupplyOption({
  required BuildContext context,
  required String title,
  required List<(String value, String label)> options,
  required String? selected,
}) {
  return showSacSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final c = sheetContext.sac;
      final theme = Theme.of(sheetContext);
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.6,
            ),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusLG),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: c.border,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusFull),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(title, style: theme.textTheme.headlineSmall),
                  ),
                ),
                Divider(height: 1, color: c.divider),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.45,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: options.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: c.divider),
                    itemBuilder: (context, index) {
                      final option = options[index];
                      final isSelected = option.$1 == selected;
                      return ListTile(
                        key: Key('camporee-supply-option-${option.$1}'),
                        title: Text(
                          option.$2,
                          style: TextStyle(
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: c.text,
                          ),
                        ),
                        trailing: isSelected
                            ? HugeIcon(
                                icon: HugeIcons.strokeRoundedTick02,
                                size: 20,
                                color: theme.colorScheme.primary,
                              )
                            : null,
                        onTap: () => Navigator.pop(sheetContext, option.$1),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

List<String> _datesBetween(String start, String end) {
  final startDate = DateTime.tryParse(start);
  final endDate = DateTime.tryParse(end);
  if (startDate == null || endDate == null || endDate.isBefore(startDate)) {
    return const [];
  }
  final dates = <String>[];
  var cursor = DateTime.utc(startDate.year, startDate.month, startDate.day);
  final last = DateTime.utc(endDate.year, endDate.month, endDate.day);
  while (!cursor.isAfter(last)) {
    dates.add(
      '${cursor.year.toString().padLeft(4, '0')}-'
      '${cursor.month.toString().padLeft(2, '0')}-'
      '${cursor.day.toString().padLeft(2, '0')}',
    );
    cursor = cursor.add(const Duration(days: 1));
  }
  return dates;
}

String _formatSupplyDate(BuildContext context, String iso) {
  final parsed = _parseIsoDate(iso);
  if (parsed == null) return iso;
  return DateFormat.yMMMd(context.locale.toString()).format(parsed);
}

DateTime? _parseIsoDate(String iso) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(iso);
  if (match == null) return DateTime.tryParse(iso);
  return DateTime(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
}

String _formatQty(double qty) {
  if (qty == qty.roundToDouble()) return qty.toStringAsFixed(0);
  return qty.toString();
}

String _formatPesos(int centavos) {
  final pesos = centavos / 100;
  return '\$${pesos.toStringAsFixed(2)}';
}

String _paymentKindLabel(String kind) {
  switch (kind) {
    case 'PRINCIPAL':
      return 'camporee_supplies.plan.kind_principal'.tr();
    case 'CHARGE':
      return 'camporee_supplies.plan.kind_charge'.tr();
    case 'REFUND':
      return 'camporee_supplies.plan.kind_refund'.tr();
    default:
      return kind;
  }
}

String _paymentStatusLabel(String status) {
  switch (status) {
    case 'ISSUED':
      return 'camporee_supplies.plan.status_issued'.tr();
    case 'PAID':
      return 'camporee_supplies.plan.status_paid'.tr();
    case 'CANCELLED':
      return 'camporee_supplies.plan.status_cancelled'.tr();
    default:
      return status;
  }
}
