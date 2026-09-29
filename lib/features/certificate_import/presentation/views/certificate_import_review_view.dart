import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';

import '../../domain/entities/certificate_import_payloads.dart';
import '../../domain/entities/certificate_import_batch.dart';
import '../../domain/entities/certificate_import_item.dart';
import '../../domain/usecases/add_certificate_import_item.dart';
import '../../domain/usecases/remove_certificate_import_item.dart';
import '../../domain/usecases/update_certificate_import_item.dart';
import '../providers/certificate_import_providers.dart';
import '../widgets/certificate_import_back_button.dart';
import '../widgets/certificate_import_item_card.dart';
import '../widgets/certificate_import_proof_card.dart';
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
        extendBodyBehindAppBar: true,
        appBar: SacTopBar(
            title: 'certificate_import.review.title'.tr(),
            leading: const CertificateImportBackButton(
              fallbackLocation: RouteNames.certificateImportUpload,
            ),
            frosted: true),
        body: SacFrostedVeil(
          child: Builder(
            builder: (context) => Padding(
              padding: EdgeInsets.only(top: SacTopBar.frostedInset(context)),
              child: Center(
                child: Text(
                  'certificate_import.review.load_error'.tr(
                    namedArgs: {'error': '$error'},
                  ),
                ),
              ),
            ),
          ),
        ),
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
        onAddItem: (item) async {
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
          final result = await ref.read(addCertificateImportItemProvider).call(
                AddCertificateImportItemParams(
                  batchId: batch.id,
                  payload: payload,
                ),
              );
          return result.fold(
            (failure) => throw Exception(failure.message),
            (created) => created,
          );
        },
        onRemoveItem: (item) async {
          final result =
              await ref.read(removeCertificateImportItemProvider).call(
                    RemoveCertificateImportItemParams(
                      batchId: batch.id,
                      itemId: item.id,
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
    this.onAddItem,
    this.onRemoveItem,
    this.onSubmitBatch,
  });

  final CertificateImportBatch initialBatch;
  final Future<void> Function(CertificateImportItem item)? onUpdateItem;
  final Future<CertificateImportItem> Function(CertificateImportItem draft)?
      onAddItem;
  final Future<void> Function(CertificateImportItem item)? onRemoveItem;
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
    final showGmNotice = _items.any((item) => item.isGuiaMayorBase);
    final showInstitutionalNotice =
        _items.any((item) => item.isInstitutionalClass);
    final showPeriodNotice =
        _items.any((item) => item.isPendingAdministrativePeriod);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
          title: 'certificate_import.review.title'.tr(),
          leading: const CertificateImportBackButton(
            fallbackLocation: RouteNames.certificateImportUpload,
          ),
          frosted: true),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => Stack(
            children: [
              CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                      child: SizedBox(height: SacTopBar.frostedInset(context))),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('certificate_import.review.found'.tr(),
                              style: TextStyle(color: c.textSecondary)),
                          const SizedBox(height: 2),
                          Text(
                            '${(_honorCount == 1 ? 'certificate_import.review.honor_one' : 'certificate_import.review.honor_other').tr(namedArgs: {
                                  'count': '$_honorCount'
                                })} ${'certificate_import.review.and'.tr()} ${(_classCount == 1 ? 'certificate_import.review.class_one' : 'certificate_import.review.class_other').tr(namedArgs: {
                                  'count': '$_classCount'
                                })}',
                            style: Theme.of(context)
                                .textTheme
                                .displaySmall
                                ?.copyWith(
                                  color: c.text,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'certificate_import.review.independent_hint'.tr(),
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: c.textSecondary,
                                    ),
                          ),
                          if (widget.initialBatch.files.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: SacPressable(
                                listenOnly: true,
                                child: TextButton(
                                  style:
                                      const ButtonStyle(enableFeedback: false),
                                  onPressed: () {
                                    final file =
                                        widget.initialBatch.files.first;
                                    context.push(
                                      RouteNames.certificateImportProof,
                                      extra: CertificateImportProofArgs(
                                        item: _items.isEmpty
                                            ? null
                                            : _items.first,
                                        batchId: widget.initialBatch.id,
                                        fileId: file.id,
                                      ),
                                    );
                                  },
                                  child: Text(
                                    'certificate_import.review.view_proof'.tr(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (showGmNotice) ...[
                            const SizedBox(height: 10),
                            _InfoNotice(
                              text:
                                  'certificate_import.review.gm01_replace'.tr(),
                            ),
                          ],
                          if (showInstitutionalNotice) ...[
                            const SizedBox(height: 10),
                            _InfoNotice(
                              text: 'certificate_import.review.institutional'
                                  .tr(),
                            ),
                          ],
                          if (showPeriodNotice) ...[
                            const SizedBox(height: 10),
                            _InfoNotice(
                              text: 'certificate_import.review.period_pending'
                                  .tr(),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _FilterButton(
                                label: 'certificate_import.review.filter_all'
                                    .tr(namedArgs: {
                                  'count': '${_items.length}'
                                }),
                                selected: _filter == 'all',
                                onPressed: () =>
                                    setState(() => _filter = 'all'),
                              ),
                              _FilterButton(
                                label: 'certificate_import.review.filter_ready'
                                    .tr(namedArgs: {'count': '$_readyCount'}),
                                selected: _filter == 'ready',
                                onPressed: () =>
                                    setState(() => _filter = 'ready'),
                              ),
                              _FilterButton(
                                label:
                                    'certificate_import.review.filter_missing'
                                        .tr(namedArgs: {
                                  'count': '$_missingCount'
                                }),
                                selected: _filter == 'missing',
                                onPressed: () =>
                                    setState(() => _filter = 'missing'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SacButton.outline(
                            text: 'certificate_import.review.add_row'.tr(),
                            onPressed: _openAddEditor,
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
                          child: Text(
                              'certificate_import.review.empty_filter'.tr(),
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
                            onRemove: widget.onRemoveItem == null
                                ? null
                                : () => _removeItem(item),
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
                              SacBadge.success(
                                  label: 'certificate_import.review.ready_dock'
                                      .tr(namedArgs: {
                                'count': '$_readyCount'
                              })),
                              const SizedBox(width: 8),
                              SacBadge.warning(
                                  label:
                                      'certificate_import.review.missing_dock'
                                          .tr(namedArgs: {
                                'count': '$_missingCount'
                              })),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SacButton.primary(
                            text: 'certificate_import.review.submit'.tr(),
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
        ),
      ),
    );
  }

  Future<void> _openAddEditor() async {
    final draft = CertificateImportItem(
      id: 'new',
      batchId: widget.initialBatch.id,
      type: CertificateImportItemType.clazz,
      status: CertificateImportItemStatus.needsReview,
    );
    await showSacSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => CertificateImportItemEditorSheet(
        item: draft,
        titleKey: 'certificate_import.editor.add_title',
        onSave: (updated) async {
          if (widget.onAddItem == null) return;
          final created = await widget.onAddItem!(updated);
          setState(() => _items = [..._items, created]);
        },
      ),
    );
  }

  Future<void> _openEditor(CertificateImportItem item) async {
    await showSacSheet<void>(
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

  Future<void> _removeItem(CertificateImportItem item) async {
    await widget.onRemoveItem?.call(item);
    setState(() {
      _items = _items.where((current) => current.id != item.id).toList();
    });
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

class _InfoNotice extends StatelessWidget {
  const _InfoNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return SacCard(
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: c.textSecondary,
            ),
      ),
    );
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
