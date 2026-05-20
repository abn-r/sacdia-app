import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';

import '../../data/datasources/certificate_import_remote_data_source.dart';
import '../../domain/entities/certificate_import_batch.dart';
import '../../domain/entities/certificate_import_item.dart';
import '../../domain/usecases/update_certificate_import_item.dart';
import '../providers/certificate_import_providers.dart';
import '../widgets/certificate_import_item_card.dart';
import '../widgets/certificate_import_item_editor_sheet.dart';

class CertificateImportReviewRouteView extends ConsumerWidget {
  const CertificateImportReviewRouteView({super.key, required this.batchId});

  final String batchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batchAsync = ref.watch(certificateImportBatchProvider(batchId));
    return batchAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Revisá los datos')),
        body: Center(child: Text('No pudimos cargar el lote: $error')),
      ),
      data: (batch) => CertificateImportReviewView(
        initialBatch: batch,
        onUpdateItem: (item) async {
          final payload = CertificateImportItemUpdatePayload(
            itemType: item.type == CertificateImportItemType.honor
                ? 'HONOR'
                : 'CLASS',
            honorId: item.honorId,
            classId: item.classId,
            detectedName: item.detectedName,
            completedAt: _apiDate(item.completedAt),
            markAsReady: item.status == CertificateImportItemStatus.ready,
          );
          final result =
              await ref.read(updateCertificateImportItemProvider).call(
                    UpdateCertificateImportItemParams(
                      batchId: batch.id,
                      itemId: item.id,
                      payload: payload,
                    ),
                  );
          result.fold((failure) => throw Exception(failure.message), (_) {});
        },
        onSubmitBatch: () async {
          final result = await ref
              .read(submitCertificateImportBatchProvider)
              .call(batch.id);
          result.fold(
            (failure) => throw Exception(failure.message),
            (_) => context.go(RouteNames.certificateImportStatusPath(batch.id)),
          );
        },
      ),
    );
  }

  static String? _apiDate(DateTime? date) {
    if (date == null) return null;
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class CertificateImportReviewView extends StatefulWidget {
  const CertificateImportReviewView({
    super.key,
    required this.initialBatch,
    this.onUpdateItem,
    this.onSubmitBatch,
  });

  final CertificateImportBatch initialBatch;
  final Future<void> Function(CertificateImportItem item)? onUpdateItem;
  final Future<void> Function()? onSubmitBatch;

  @override
  State<CertificateImportReviewView> createState() =>
      _CertificateImportReviewViewState();
}

class _CertificateImportReviewViewState
    extends State<CertificateImportReviewView> {
  late List<CertificateImportItem> _items;
  bool _submitting = false;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.initialBatch.items);
  }

  bool get _canSubmit => _items.isNotEmpty && _items.every(_isComplete);

  int get _honorCount => _items
      .where((item) => item.type == CertificateImportItemType.honor)
      .length;
  int get _classCount => _items
      .where((item) => item.type == CertificateImportItemType.clazz)
      .length;
  int get _readyCount => _items.where(_isComplete).length;
  int get _missingCount => _items.length - _readyCount;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final visibleItems = _items.where((item) {
      if (_filter == 'ready') return _isComplete(item);
      if (_filter == 'missing') return !_isComplete(item);
      return true;
    }).toList(growable: false);

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: const Text('Revisá los datos')),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Encontramos',
                          style: TextStyle(color: c.textSecondary)),
                      const SizedBox(height: 2),
                      Text(
                        '$_honorCount ${_honorCount == 1 ? 'especialidad' : 'especialidades'} y $_classCount ${_classCount == 1 ? 'clase' : 'clases'}',
                        style:
                            Theme.of(context).textTheme.displaySmall?.copyWith(
                                  color: c.text,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _FilterButton(
                            label: 'Todas ${_items.length}',
                            selected: _filter == 'all',
                            onPressed: () => setState(() => _filter = 'all'),
                          ),
                          _FilterButton(
                            label: 'Listas $_readyCount',
                            selected: _filter == 'ready',
                            onPressed: () => setState(() => _filter = 'ready'),
                          ),
                          _FilterButton(
                            label: 'Falta dato $_missingCount',
                            selected: _filter == 'missing',
                            onPressed: () =>
                                setState(() => _filter = 'missing'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (visibleItems.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SacCard(
                      child: Text('No hay filas para este filtro.',
                          style: TextStyle(color: c.textSecondary)),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 150),
                  sliver: SliverList.separated(
                    itemCount: visibleItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = visibleItems[index];
                      return CertificateImportItemCard(
                        item: item,
                        onEdit: () => _openEditor(item),
                      );
                    },
                  ),
                ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: c.background,
                border: Border(top: BorderSide(color: c.border)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          SacBadge.success(label: '$_readyCount listas'),
                          const SizedBox(width: 8),
                          SacBadge.warning(
                              label: '$_missingCount con datos faltantes'),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SacButton.primary(
                        text: 'Enviar a revisión',
                        isEnabled: _canSubmit,
                        isLoading: _submitting,
                        onPressed: _canSubmit ? _submit : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditor(CertificateImportItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => CertificateImportItemEditorSheet(
        item: item,
        onSave: (updated) async {
          await widget.onUpdateItem?.call(updated);
          setState(() {
            _items = _items
                .map((current) => current.id == updated.id ? updated : current)
                .toList(growable: false);
          });
        },
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await widget.onSubmitBatch?.call();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  bool _isComplete(CertificateImportItem item) {
    final hasCatalog = item.type == CertificateImportItemType.honor
        ? item.honorId != null
        : item.classId != null;
    return item.type != CertificateImportItemType.unknown &&
        (item.detectedName?.trim().isNotEmpty ?? false) &&
        item.completedAt != null &&
        hasCatalog;
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SacButton(
      text: label,
      size: SacButtonSize.small,
      fullWidth: false,
      variant: selected ? SacButtonVariant.primary : SacButtonVariant.outline,
      onPressed: onPressed,
    );
  }
}
