import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_back_button.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/features/camporee_orders/domain/entities/camporee_order.dart';
import 'package:sacdia_app/features/camporee_orders/presentation/providers/camporee_orders_providers.dart';
import 'package:sacdia_app/features/camporee_supplies/domain/entities/camporee_supply_plan.dart';
import 'package:sacdia_app/features/camporee_supplies/presentation/providers/camporee_supplies_providers.dart';
import 'package:sacdia_app/features/camporees/presentation/providers/camporees_providers.dart';
import 'package:sacdia_app/features/camporees/presentation/widgets/camporee_participant_access_gate.dart';

class CamporeeSuppliesCta extends ConsumerWidget {
  final int camporeeId;
  final CamporeeKind camporeeType;

  const CamporeeSuppliesCta({
    super.key,
    required this.camporeeId,
    this.camporeeType = CamporeeKind.local,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registrationAsync =
        ref.watch(camporeeSectionRegistrationProvider(camporeeId));
    if (!camporeeParticipantsAreEnabled(registrationAsync)) {
      return const SizedBox.shrink();
    }

    final scope = CamporeeSuppliesScope(
      camporeeId: camporeeId,
      type: camporeeType,
    );
    final planAsync = ref.watch(camporeeSupplyPlanProvider(scope));

    return planAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (error, _) {
        final code = error is Failure ? error.code : null;
        if (code == 403 || code == 404) return const SizedBox.shrink();
        return const SizedBox.shrink();
      },
      data: (envelope) {
        if (!envelope.catalog.isReady) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: SacButton.primary(
            key: const Key('camporee-supplies-cta'),
            text: 'camporee_supplies.cta.label'.tr(),
            icon: HugeIcons.strokeRoundedInvoice01,
            onPressed: () => context.push(
              RouteNames.camporeeSuppliesPath(
                camporeeId,
                type: camporeeType == CamporeeKind.union ? 'union' : 'local',
              ),
            ),
            labelMaxLines: 2,
            labelOverflow: TextOverflow.visible,
          ),
        );
      },
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

class _CamporeeSupplyPlanViewState extends ConsumerState<CamporeeSupplyPlanView> {
  String? _date;
  String? _slotId;
  String? _productId;
  final _qtyController = TextEditingController(text: '1');
  List<CamporeeSupplyLineInput> _draftLines = [];

  CamporeeSuppliesScope get _scope => CamporeeSuppliesScope(
        camporeeId: widget.camporeeId,
        type: widget.camporeeType,
      );

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final envelopeAsync = ref.watch(camporeeSupplyPlanProvider(_scope));
    final c = context.sac;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        leading: const SacBackButton(),
        title: Text('camporee_supplies.plan.title'.tr()),
      ),
      body: envelopeAsync.when(
        loading: () => const SacLoading(),
        error: (error, _) => Center(
          child: Text(camporeeSuppliesErrorMessage(error)),
        ),
        data: (envelope) {
          final plan = envelope.plan;
          if (_draftLines.isEmpty && plan != null && plan.isDraft) {
            _draftLines = plan.lines.map((line) => line.toInput()).toList();
          }
          final dates = _datesBetween(
            envelope.catalog.startDate,
            envelope.catalog.endDate,
          );
          _date ??= dates.isEmpty ? null : dates.first;
          _slotId ??= envelope.catalog.slots.isEmpty
              ? null
              : envelope.catalog.slots.first.slotId;
          _productId ??= envelope.catalog.products.isEmpty
              ? null
              : envelope.catalog.products.first.productId;

          final submitted = plan?.isSubmitted == true;
          final lines = submitted
              ? plan!.lines.map((line) => line.toInput()).toList()
              : _draftLines;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'camporee_supplies.plan.cutoff'.tr(
                  namedArgs: {'time': envelope.catalog.cutoff},
                ),
                style: TextStyle(color: c.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              if (!envelope.catalog.isReady)
                Text('camporee_supplies.plan.catalog_empty'.tr())
              else ...[
                _AddRow(
                  dates: dates,
                  catalog: envelope.catalog,
                  date: _date,
                  slotId: _slotId,
                  productId: _productId,
                  qtyController: _qtyController,
                  onDate: (value) => setState(() => _date = value),
                  onSlot: (value) => setState(() => _slotId = value),
                  onProduct: (value) => setState(() => _productId = value),
                  onAdd: () => _addLine(submitted),
                ),
                const SizedBox(height: 16),
                if (lines.isEmpty)
                  Text('camporee_supplies.plan.empty'.tr())
                else
                  ...lines.map(
                    (line) => _LineTile(
                      line: line,
                      catalog: envelope.catalog,
                      onRemove: submitted
                          ? null
                          : () => setState(
                                () => _draftLines.removeWhere(
                                  (row) =>
                                      row.date == line.date &&
                                      row.slotId == line.slotId &&
                                      row.productId == line.productId,
                                ),
                              ),
                    ),
                  ),
                const SizedBox(height: 16),
                if (plan != null) ...[
                  Text(
                    'camporee_supplies.plan.net'.tr(
                      namedArgs: {
                        'amount': _formatPesos(plan.netCentavos),
                      },
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  ...plan.payments.map(
                    (payment) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(payment.folioReference),
                      subtitle: Text(
                        '${payment.kind} · ${payment.status}',
                      ),
                      trailing: Text(_formatPesos(payment.totalCentavos)),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (!submitted) ...[
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

  Future<void> _addLine(bool submitted) async {
    final qty = double.tryParse(_qtyController.text.replaceAll(',', '.'));
    if (_date == null ||
        _slotId == null ||
        _productId == null ||
        qty == null ||
        qty <= 0) {
      return;
    }
    final input = CamporeeSupplyLineInput(
      date: _date!,
      slotId: _slotId!,
      productId: _productId!,
      qty: qty,
    );
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
    final result = await ref.read(camporeeSuppliesRepositoryProvider).replaceDraft(
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
    final saved = await ref.read(camporeeSuppliesRepositoryProvider).replaceDraft(
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          value: date,
          decoration: InputDecoration(
            labelText: 'camporee_supplies.plan.date'.tr(),
          ),
          items: dates
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: onDate,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: slotId,
          decoration: InputDecoration(
            labelText: 'camporee_supplies.plan.slot'.tr(),
          ),
          items: catalog.slots
              .map(
                (slot) => DropdownMenuItem(
                  value: slot.slotId,
                  child: Text('${slot.label} (${slot.deliverTime})'),
                ),
              )
              .toList(),
          onChanged: onSlot,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: productId,
          decoration: InputDecoration(
            labelText: 'camporee_supplies.plan.product'.tr(),
          ),
          items: catalog.products
              .map(
                (product) => DropdownMenuItem(
                  value: product.productId,
                  child: Text(
                    '${product.name} · ${_formatPesos(product.unitCostCentavos)}/${product.uom}',
                  ),
                ),
              )
              .toList(),
          onChanged: onProduct,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: qtyController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          decoration: InputDecoration(
            labelText: 'camporee_supplies.plan.qty'.tr(),
          ),
        ),
        const SizedBox(height: 8),
                  SacButton.outline(
          text: 'camporee_supplies.plan.add'.tr(),
          onPressed: onAdd,
        ),
      ],
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
    final slot = catalog.slots.where((item) => item.slotId == line.slotId);
    final product =
        catalog.products.where((item) => item.productId == line.productId);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(product.isEmpty ? line.productId : product.first.name),
      subtitle: Text(
        '${line.date} · ${slot.isEmpty ? line.slotId : slot.first.label} · ${line.qty}',
      ),
      trailing: onRemove == null
          ? null
          : IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.close),
            ),
    );
  }
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

String _formatPesos(int centavos) {
  final pesos = centavos / 100;
  return '\$${pesos.toStringAsFixed(2)}';
}
