import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/animations/staggered_list_animation.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_filter_chip.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';

import '../../domain/entities/certificate_import_batch.dart';
import '../../domain/entities/certificate_import_error_code.dart';
import '../../domain/entities/certificate_import_item.dart';
import '../../domain/entities/certificate_import_ocr_state.dart';
import '../../domain/entities/certificate_import_payloads.dart';
import '../../domain/entities/certificate_proof_target.dart';
import '../../domain/usecases/add_certificate_import_item.dart';
import '../../domain/usecases/remove_certificate_import_item.dart';
import '../../domain/usecases/update_certificate_import_item.dart';
import '../error/certificate_import_error_mapper.dart';
import '../providers/certificate_import_providers.dart';
import '../widgets/certificate_import_back_button.dart';
import '../widgets/certificate_import_item_card.dart';
import '../widgets/certificate_import_item_editor_sheet.dart';
import '../widgets/certificate_proof_summary.dart';
import '../widgets/certificate_proof_viewer.dart';
import '../widgets/import_load_error_scaffold.dart';
import '../widgets/import_review_dock.dart';
import '../widgets/import_review_empty.dart';
import '../widgets/import_row_presence.dart';

class CertificateImportReviewRouteView extends ConsumerWidget {
  const CertificateImportReviewRouteView({
    super.key,
    required this.batchId,
    this.localPath,
  });

  final String batchId;

  /// Local file just uploaded, when arriving from the upload flow.
  final String? localPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batchAsync = ref.watch(certificateImportBatchProvider(batchId));
    return batchAsync.when(
      loading: () => const Scaffold(body: Center(child: SacLoading())),
      error: (_, __) => ImportLoadErrorScaffold(
        title: 'certificate_import.review.title'.tr(),
        bodyKey: 'certificate_import.review.load_error',
        fallbackLocation: RouteNames.certificateImportUpload,
        onRetry: () => ref.invalidate(certificateImportBatchProvider(batchId)),
      ),
      data: (batch) => CertificateImportReviewView(
        initialBatch: batch,
        proofLocalPath: localPath,
        onFetchBatch: () async {
          final result =
              await ref.read(getCertificateImportBatchProvider).call(batch.id);
          return result.fold((failure) => throw failure, (next) => next);
        },
        onRetryRead: () async {
          final result = await ref
              .read(processCertificateImportOcrProvider)
              .call(batch.id);
          return result.fold((failure) => throw failure, (next) => next);
        },
        onChooseOtherFile: () => context.go(RouteNames.certificateImportUpload),
        onUpdateItem: (item, previous) async {
          final result =
              await ref.read(updateCertificateImportItemProvider).call(
                    UpdateCertificateImportItemParams(
                      batchId: batch.id,
                      itemId: item.id,
                      payload: _payload(item, previous: previous),
                    ),
                  );
          return result.fold((failure) => throw failure, (saved) => saved);
        },
        onAddItem: (item) async {
          final result = await ref.read(addCertificateImportItemProvider).call(
                AddCertificateImportItemParams(
                  batchId: batch.id,
                  payload: _payload(item),
                ),
              );
          return result.fold((failure) => throw failure, (created) => created);
        },
        onRemoveItem: (item) async {
          final result =
              await ref.read(removeCertificateImportItemProvider).call(
                    RemoveCertificateImportItemParams(
                      batchId: batch.id,
                      itemId: item.id,
                    ),
                  );
          result.fold((failure) => throw failure, (_) {});
        },
        onSubmitBatch: () async {
          final result = await ref
              .read(submitCertificateImportBatchProvider)
              .call(batch.id);
          result.fold(
            (failure) => throw failure,
            (_) {
              // The status screen reads the same provider this screen loaded
              // before the member removed rows: drop the cached batch so it
              // counts what was really sent. The entry list shows its status.
              ref.invalidate(certificateImportBatchProvider(batch.id));
              ref.invalidate(certificateImportBatchListProvider);
              context.go(RouteNames.certificateImportStatusPath(batch.id));
            },
          );
        },
      ),
    );
  }

  static CertificateImportItemUpdatePayload _payload(
    CertificateImportItem item, {
    CertificateImportItem? previous,
  }) =>
      CertificateImportItemUpdatePayload.fromItem(item, previous: previous);
}

class CertificateImportReviewView extends StatefulWidget {
  const CertificateImportReviewView({
    super.key,
    required this.initialBatch,
    this.proofLocalPath,
    this.onUpdateItem,
    this.onAddItem,
    this.onRemoveItem,
    this.onSubmitBatch,
    this.onFetchBatch,
    this.onRetryRead,
    this.onChooseOtherFile,
  });

  final CertificateImportBatch initialBatch;

  /// Local copy of the proof just uploaded: thumbnail and offline viewing.
  final String? proofLocalPath;

  /// Returns the row as the API saved it (with its catalog names).
  final Future<CertificateImportItem> Function(
    CertificateImportItem item,
    CertificateImportItem previous,
  )? onUpdateItem;
  final Future<CertificateImportItem> Function(CertificateImportItem draft)?
      onAddItem;
  final Future<void> Function(CertificateImportItem item)? onRemoveItem;
  final Future<void> Function()? onSubmitBatch;

  /// Loads the batch again: polling while it is read, pull to refresh and
  /// coming back to the app.
  final Future<CertificateImportBatch> Function()? onFetchBatch;

  /// Asks the API to read the proof again.
  final Future<CertificateImportBatch> Function()? onRetryRead;
  final VoidCallback? onChooseOtherFile;

  @override
  State<CertificateImportReviewView> createState() =>
      _CertificateImportReviewViewState();
}

class _CertificateImportReviewViewState
    extends State<CertificateImportReviewView> with WidgetsBindingObserver {
  /// How often the batch is polled while it is still being read.
  static const _pollEvery = Duration(seconds: 3);

  /// Stagger of the first results: 5 steps of 40 ms plus 200 ms, rounded up.
  static const _entranceSpan = Duration(milliseconds: 480);

  late CertificateImportBatch _batch;
  late List<CertificateImportItem> _items;
  final _scroll = ScrollController();
  final _rowKeys = <String, GlobalKey>{};
  final _timers = <Timer>[];
  Timer? _poll;
  bool _fetching = false;
  bool _submitting = false;
  bool _entered = false;
  int _edits = 0;
  String? _submitError;
  String _filter = 'all';
  Set<String> _entering = {};
  final _arriving = <String>{};
  final _leaving = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _batch = widget.initialBatch;
    _items = List.of(_batch.activeItems);
    _markEntrance();
    _syncPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    for (final timer in _timers) {
      timer.cancel();
    }
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isReading) {
      _refresh(quiet: true);
    }
  }

  void _later(Duration delay, VoidCallback action) {
    _timers.add(Timer(delay, () {
      if (mounted) action();
    }));
  }

  bool get _isReading =>
      _batch.ocrState == CertificateImportOcrState.pending ||
      _batch.ocrState == CertificateImportOcrState.running;

  GlobalKey _rowKey(String id) => _rowKeys.putIfAbsent(id, GlobalKey.new);

  /// First results play the stagger once (M10); filtering or returning from
  /// the editor never repeats it.
  void _markEntrance() {
    if (_entered || _items.isEmpty) return;
    _entered = true;
    _entering = _items.map((item) => item.id).toSet();
    _later(_entranceSpan, () => setState(() => _entering = {}));
  }

  void _syncPolling() {
    if (_isReading && widget.onFetchBatch != null) {
      _poll ??= Timer.periodic(_pollEvery, (_) => _refresh(quiet: true));
    } else {
      _poll?.cancel();
      _poll = null;
    }
  }

  /// Loads the latest batch. A result that arrives after the member edited a
  /// row is dropped: the edit already holds the newer data.
  Future<void> _refresh({bool quiet = false}) async {
    final fetch = widget.onFetchBatch;
    if (fetch == null || _fetching) return;
    _fetching = true;
    final edits = _edits;
    try {
      final next = await fetch();
      if (mounted && edits == _edits) _applyBatch(next);
    } catch (error) {
      if (mounted && !quiet) {
        SacSnackBar.show(
          context,
          CertificateImportErrorMapper.message(error),
          isError: true,
        );
      }
    } finally {
      _fetching = false;
    }
  }

  void _applyBatch(CertificateImportBatch next) {
    setState(() {
      _batch = next;
      _items = List.of(next.activeItems);
      _markEntrance();
    });
    _syncPolling();
  }

  Future<void> _retryRead() async {
    final retry = widget.onRetryRead;
    if (retry == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final next = await retry();
      if (mounted) _applyBatch(next);
    } catch (error) {
      SacSnackBar.showMessenger(
        messenger,
        CertificateImportErrorMapper.message(error),
        isError: true,
      );
    }
  }

  List<CertificateImportItem> get _honors =>
      _items.where((i) => i.type != CertificateImportItemType.clazz).toList();
  List<CertificateImportItem> get _classes =>
      _items.where((i) => i.type == CertificateImportItemType.clazz).toList();
  int get _readyCount => _items.where((i) => i.isComplete).length;
  int get _missingCount => _items.length - _readyCount;

  bool _passesFilter(CertificateImportItem item) => switch (_filter) {
        'ready' => item.isComplete,
        'missing' => !item.isComplete,
        _ => true,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final empty = _items.isEmpty;
    final visible = _items.where(_passesFilter).toList(growable: false);
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
              RefreshIndicator(
                edgeOffset: SacTopBar.frostedInset(context),
                onRefresh: () => _refresh(),
                child: SingleChildScrollView(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.only(bottom: empty ? 24 : 190),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: SacTopBar.frostedInset(context)),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!empty) ..._summaryHeader(context),
                            if (_batch.files.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: CertificateProofSummary(
                                  batchId: _batch.id,
                                  files: _batch.files,
                                  localPath: widget.proofLocalPath,
                                ),
                              ),
                            if (!empty && _isReading)
                              _InfoNotice(
                                text: 'certificate_import.review.still_reading'
                                    .tr(),
                              ),
                            for (final notice in [
                              if (showGmNotice)
                                'certificate_import.review.gm01_replace',
                              if (showInstitutionalNotice)
                                'certificate_import.review.institutional',
                              if (showPeriodNotice)
                                'certificate_import.review.period_pending',
                            ])
                              _InfoNotice(text: notice.tr()),
                            if (!empty) _filters(),
                          ],
                        ),
                      ),
                      if (empty)
                        ImportReviewEmpty(
                          kind: _emptyKind,
                          error: _emptyKind == ImportReviewEmptyKind.failed
                              ? CertificateImportErrorMapper.mapCode(
                                  CertificateImportErrorCode.known(
                                        _batch.ocrErrorCode,
                                      ) ??
                                      CertificateImportErrorCode.ocrFailed,
                                )
                              : null,
                          onAdd: _openAddEditor,
                          onRetryRead:
                              widget.onRetryRead == null ? null : _retryRead,
                          onChooseOtherFile: widget.onChooseOtherFile,
                        )
                      else if (visible.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: SacCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    'certificate_import.review.empty_filter'
                                        .tr(),
                                    style: TextStyle(color: c.textSecondary)),
                                SacButton.ghost(
                                  text:
                                      'certificate_import.review.show_all'.tr(),
                                  onPressed: () =>
                                      setState(() => _filter = 'all'),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ..._groups(visible),
                      if (!empty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                          child: SacButton.outline(
                            text: 'certificate_import.review.add_row'.tr(),
                            onPressed: _openAddEditor,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (!empty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ImportReviewDock(
                    total: _items.length,
                    readyCount: _readyCount,
                    isSending: _submitting,
                    error: _submitError,
                    onComplete: _completeNext,
                    onSend: _confirmAndSubmit,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  ImportReviewEmptyKind get _emptyKind {
    if (!_batch.hasOcrState) return ImportReviewEmptyKind.empty;
    final state = _batch.ocrState;
    if (state == null) return ImportReviewEmptyKind.none;
    if (state == CertificateImportOcrState.failed) {
      return ImportReviewEmptyKind.failed;
    }
    return state.isTerminal
        ? ImportReviewEmptyKind.empty
        : ImportReviewEmptyKind.reading;
  }

  List<Widget> _summaryHeader(BuildContext context) {
    final c = context.sac;
    final theme = Theme.of(context).textTheme;
    return [
      Text('certificate_import.review.found'.tr(),
          style: TextStyle(color: c.textSecondary)),
      const SizedBox(height: 2),
      Text(
        _summary(),
        style: theme.displaySmall?.copyWith(
          color: c.text,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 4),
      Text('certificate_import.review.hint'.tr(),
          style: theme.bodySmall?.copyWith(color: c.textSecondary)),
      const SizedBox(height: 12),
    ];
  }

  Widget _filters() {
    Widget chip(String id, String key, int count) => SacFilterChip(
          label: key.tr(),
          count: count,
          selected: _filter == id,
          variant: SacFilterChipVariant.quiet,
          onTap: () => setState(() => _filter = id),
        );
    return Wrap(
      spacing: 8,
      children: [
        chip('all', 'certificate_import.review.filter_all', _items.length),
        chip('ready', 'certificate_import.review.filter_ready', _readyCount),
        if (_missingCount > 0)
          chip('missing', 'certificate_import.review.filter_missing',
              _missingCount),
      ],
    );
  }

  /// Honor and class groups, each with a counted header. The OCR order (the
  /// document order) is kept inside a group.
  List<Widget> _groups(List<CertificateImportItem> visible) {
    var index = 0;
    final groups = [
      ('certificate_import.review.group_honors', _honors),
      ('certificate_import.review.group_classes', _classes),
    ];
    return [
      for (final (titleKey, all) in groups)
        if (all.any(visible.contains)) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              titleKey.tr(namedArgs: {'count': '${all.length}'}).toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.sac.textTertiary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
            ),
          ),
          for (final item in all.where(visible.contains)) _row(item, index++),
        ],
    ];
  }

  Widget _row(CertificateImportItem item, int index) {
    final target = CertificateProofTarget.resolve(_batch.files, item: item);
    return ImportRowPresence(
      key: ValueKey('row-${item.id}'),
      visible: !_leaving.contains(item.id),
      animateIn: _arriving.contains(item.id),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: KeyedSubtree(
          key: _rowKey(item.id),
          child: StaggeredListItem(
            index: index,
            animate: _entering.contains(item.id),
            child: CertificateImportItemCard(
              item: item,
              onEdit: () => _openEditor(item),
              onViewProof: target == null ? null : () => _openProof(item),
              proofPage: _proofPage(item),
            ),
          ),
        ),
      ),
    );
  }

  /// Page to name on the proof button; only when the row has a known one.
  int? _proofPage(CertificateImportItem item) {
    final target = CertificateProofTarget.resolve(_batch.files, item: item);
    return target != null && target.page == item.sourcePage
        ? target.page
        : null;
  }

  void _openProof(CertificateImportItem item) {
    final target = CertificateProofTarget.resolve(_batch.files, item: item);
    if (target == null) return;
    CertificateProofViewer.open(
      context,
      batchId: _batch.id,
      file: target.file,
      initialPage: target.page,
      localPath: target.file.id == _batch.files.first.id
          ? widget.proofLocalPath
          : null,
    );
  }

  /// Scrolls to the first incomplete row, then opens its editor (M16).
  Future<void> _completeNext() async {
    final next = [..._honors, ..._classes].where((i) => !i.isComplete);
    if (next.isEmpty) return;
    final item = next.first;
    if (_filter == 'ready') setState(() => _filter = 'all');
    final rowContext = _rowKeys[item.id]?.currentContext;
    if (rowContext != null) {
      await Scrollable.ensureVisible(
        rowContext,
        alignment: 0.15,
        duration:
            SacMotion.reduceMotionOf(context) ? Duration.zero : SacMotion.modal,
        curve: SacMotion.easeInOut,
      );
    }
    if (mounted) await _openEditor(item);
  }

  Future<void> _openAddEditor() async {
    final draft = CertificateImportItem(
      id: 'new',
      batchId: _batch.id,
      type: CertificateImportItemType.honor,
      status: CertificateImportItemStatus.needsReview,
    );
    await showCertificateImportItemEditor(
      context,
      item: draft,
      isNew: true,
      onSave: (updated) async {
        if (widget.onAddItem == null) return;
        final created = await widget.onAddItem!(updated);
        _edits++;
        if (!mounted) return;
        setState(() {
          _items = [..._items, created];
          _arriving.add(created.id);
          _filter = 'all';
          _markEntrance();
        });
        _later(SacMotion.standard, () => _arriving.remove(created.id));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final rowContext = _rowKeys[created.id]?.currentContext;
          if (rowContext == null || !mounted) return;
          Scrollable.ensureVisible(
            rowContext,
            duration: SacMotion.reduceMotionOf(rowContext)
                ? Duration.zero
                : SacMotion.modal,
            curve: SacMotion.easeInOut,
          );
        });
      },
    );
  }

  Future<void> _openEditor(CertificateImportItem item) async {
    await showCertificateImportItemEditor(
      context,
      item: item,
      onViewProof: _batch.files.isEmpty ? null : () => _openProof(item),
      proofPage: _proofPage(item),
      onRemove: widget.onRemoveItem == null
          ? null
          : () {
              Navigator.of(context).pop();
              _removeItem(item);
            },
      onSave: (updated) async {
        final saved = await widget.onUpdateItem?.call(updated, item) ?? updated;
        _edits++;
        if (!mounted) return;
        setState(() {
          _items = _items
              .map((current) => current.id == saved.id ? saved : current)
              .toList(growable: false);
        });
      },
    );
  }

  /// "3 especialidades y 1 clase": only names the types that have rows.
  String _summary() {
    final honors = _items
        .where((item) => item.type == CertificateImportItemType.honor)
        .length;
    final classes = _classes.length;
    final parts = <String>[
      if (honors > 0)
        (honors == 1
                ? 'certificate_import.review.honor_one'
                : 'certificate_import.review.honor_other')
            .tr(namedArgs: {'count': '$honors'}),
      if (classes > 0)
        (classes == 1
                ? 'certificate_import.review.class_one'
                : 'certificate_import.review.class_other')
            .tr(namedArgs: {'count': '$classes'}),
    ];
    if (parts.isEmpty) return 'certificate_import.review.no_rows'.tr();
    return parts.join(' ${'certificate_import.review.and'.tr()} ');
  }

  Future<void> _removeItem(CertificateImportItem item) async {
    final isHonor = item.type == CertificateImportItemType.honor;
    final confirmed = await SacDialog.show(
      context,
      title: (isHonor
              ? 'certificate_import.review.remove_honor_title'
              : 'certificate_import.review.remove_class_title')
          .tr(),
      content: 'certificate_import.review.remove_body'.tr(),
      confirmLabel: 'certificate_import.item.remove'.tr(),
      confirmIsDestructive: true,
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.onRemoveItem?.call(item);
      if (!mounted) return;
      _edits++;
      // Fade and collapse first (M13), then drop the row from the list.
      setState(() => _leaving.add(item.id));
      _later(SacMotion.standard, () {
        setState(() {
          _items = _items.where((current) => current.id != item.id).toList();
          _leaving.remove(item.id);
          _rowKeys.remove(item.id);
        });
      });
    } catch (error) {
      SacSnackBar.showMessenger(
        messenger,
        CertificateImportErrorMapper.message(error),
        isError: true,
      );
    }
  }

  Future<void> _confirmAndSubmit() async {
    final confirmed = await SacDialog.show(
      context,
      title: 'certificate_import.review.submit_confirm_title'.tr(),
      content: 'certificate_import.review.submit_confirm_body'
          .tr(namedArgs: {'summary': _summary()}),
      confirmLabel: 'certificate_import.review.submit_confirm_action'.tr(),
    );
    if (confirmed == true && mounted) await _submit();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      await widget.onSubmitBatch?.call();
    } catch (error) {
      if (mounted) {
        final info = CertificateImportErrorMapper.map(error);
        setState(() {
          _submitError = info.kind == CertificateImportErrorKind.unknown
              ? 'certificate_import.review.submit_error'.tr()
              : info.body;
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _InfoNotice extends StatelessWidget {
  const _InfoNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SacCard(
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: c.textSecondary,
              ),
        ),
      ),
    );
  }
}
