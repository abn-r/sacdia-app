import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/animations/page_transitions.dart';
import 'package:sacdia_app/core/constants/certificate_dates.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/instructor_field.dart';
import 'package:sacdia_app/core/widgets/instructor_selection.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_filter_chip.dart';
import 'package:sacdia_app/core/widgets/sac_picker_field.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';
import 'package:sacdia_app/core/widgets/sac_text_field.dart';
import 'package:sacdia_app/features/honors/presentation/providers/honors_providers.dart';
import 'package:sacdia_app/features/profile/presentation/views/edit_profile_view.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_badge_image.dart';
import 'package:sacdia_app/providers/catalogs_provider.dart';

import '../../domain/entities/certificate_import_class_option.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import '../../domain/entities/certificate_import_item.dart';
import '../error/certificate_import_error_mapper.dart';
import 'detected_text_quote.dart';
import 'honor_picker_sheet.dart';
import 'import_class_section.dart';
import 'import_date_field.dart';
import 'import_error_banner.dart';

/// Row editor sheet. Separates what the system read (a read-only quote) from
/// what the member chooses (catalog pickers), so no catalog id is ever typed.
///
/// "Guardar" is always enabled: an incomplete row saves as a draft and the
/// line above the button says what is missing.
class CertificateImportItemEditorSheet extends ConsumerStatefulWidget {
  const CertificateImportItemEditorSheet({
    super.key,
    required this.item,
    required this.onSave,
    this.onRemove,
    this.onViewProof,
    this.proofPage,
    this.isNew = false,
    this.clock,
    this.onOpenProfile,
  });

  final CertificateImportItem item;
  final Future<void> Function(CertificateImportItem item) onSave;

  /// Shown as "Quitar de la lista" when the row can be removed.
  final VoidCallback? onRemove;

  /// Opens the proof at this row; null hides the action.
  final VoidCallback? onViewProof;

  /// Page named on the proof action, when the row has a known one.
  final int? proofPage;

  /// A row being added by hand: type chips, no quote.
  final bool isNew;

  /// "Today" for the date rule; tests inject it.
  final DateTime Function()? clock;

  /// Opens the profile editor (birthday). Defaults to pushing it over the
  /// sheet, so the member's edits stay here while they go.
  final VoidCallback? onOpenProfile;

  @override
  ConsumerState<CertificateImportItemEditorSheet> createState() =>
      _CertificateImportItemEditorSheetState();
}

class _CertificateImportItemEditorSheetState
    extends ConsumerState<CertificateImportItemEditorSheet> {
  final _scroll = ScrollController();
  final _dateKey = GlobalKey();
  final _honorKey = GlobalKey();
  final _classKey = GlobalKey();
  final _instructorKey = GlobalKey();
  late final TextEditingController _name;
  late CertificateImportItemType _type;
  late final bool _typeIsOpen;

  // Honor selection. The id survives even if the API sent no names (R6).
  int? _honorId;
  CertificateImportHonorRef? _honor;
  int? _honorClubTypeId;
  int? _categoryId;
  String? _categoryName;
  bool _suggested = false;

  // Class selection.
  int? _clubTypeId;
  CertificateImportClassOption? _class;
  int? _classId;

  // Optional (D1): never counted in "Falta..." nor in the dock.
  late final InstructorSelection _initialInstructor;
  late InstructorSelection _instructor;

  DateTime? _date;
  ImportDateHint _dateHint = ImportDateHint.none;

  bool _fixingText = false;
  bool _dirty = false;
  bool _saving = false;
  String? _honorError;
  String? _classError;
  String? _dateError;
  String? _instructorError;
  String? _banner;
  bool _bannerGoesToProfile = false;

  DateTime get _today => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _typeIsOpen =
        widget.isNew || item.type == CertificateImportItemType.unknown;
    _type = item.type == CertificateImportItemType.clazz
        ? CertificateImportItemType.clazz
        : CertificateImportItemType.honor;
    _name = TextEditingController(text: item.detectedName ?? '');
    _honorId = item.honorId;
    _honor = item.honor;
    _categoryId = item.honor?.categoryId;
    _categoryName = item.honor?.categoryName;
    _classId = item.classId;
    _clubTypeId = item.classRef?.clubTypeId;
    final ref = item.classRef;
    if (ref != null) {
      _class = CertificateImportClassOption(
        id: ref.id,
        name: ref.name,
        assetCode: ref.assetCode,
        clubTypeId: ref.clubTypeId,
      );
    }
    _initialInstructor = item.type == CertificateImportItemType.honor ||
            item.type == CertificateImportItemType.unknown
        ? _selectionOf(item.instructor)
        : const InstructorSelection.none();
    _instructor = _initialInstructor;
    // An OCR proposal waits for the member's confirmation ("Sugerida").
    _suggested = item.status == CertificateImportItemStatus.needsReview &&
        (item.honorId != null || item.classId != null);

    final read = item.detectedDate;
    final readIssue = CertificateDateRule.check(read, now: _today);
    _date = item.completedAt ?? (readIssue == null ? read : null);
    if (_date == null && (read != null || item.needsDateReview)) {
      _dateHint = ImportDateHint.unreadable;
    } else if (item.needsDateReview) {
      _dateHint = ImportDateHint.review;
    } else if (item.completedAt == null && _date != null) {
      _dateHint = ImportDateHint.read;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _touch(VoidCallback change) => setState(() {
        change();
        _dirty = true;
        _banner = null;
        _bannerGoesToProfile = false;
      });

  bool get _isHonor => _type == CertificateImportItemType.honor;

  /// [saving] is the row the member is saving: one more revision, so the
  /// "Revisa la fecha" notice (shown while editing) goes away for good.
  CertificateImportItem _make(
    CertificateImportItemStatus status, {
    bool saving = false,
  }) {
    final item = widget.item;
    final catalogName = _isHonor ? _honor?.name : _class?.name;
    final typed = _name.text.trim();
    final name = typed.isNotEmpty ? typed : (catalogName ?? '');
    final clubName = ref
        .read(clubTypesProvider)
        .valueOrNull
        ?.where((t) => t.clubTypeId == _clubTypeId)
        .map((t) => t.name)
        .firstOrNull;
    return CertificateImportItem(
      id: item.id,
      batchId: item.batchId,
      type: _type,
      honorId: _isHonor ? _honorId : null,
      classId: _isHonor ? null : _class?.id ?? _classId,
      classAssetCode:
          _isHonor ? null : _class?.assetCode ?? item.classAssetCode,
      detectedName: name.isEmpty ? null : name,
      detectedDate: item.detectedDate,
      completedAt: _date,
      ocrConfidence: item.ocrConfidence,
      fieldConfidence: item.fieldConfidence,
      status: status,
      rejectionReason: item.rejectionReason,
      appliedEntityType: item.appliedEntityType,
      appliedEntityId: item.appliedEntityId,
      sourcePage: item.sourcePage,
      sourceFileId: item.sourceFileId,
      honor: _isHonor ? _honor : null,
      classRef: _isHonor || _class == null
          ? null
          : CertificateImportClassRef(
              id: _class!.id,
              name: _class!.name,
              assetCode: _class!.assetCode,
              clubTypeId: _clubTypeId,
              clubTypeName: clubName,
            ),
      instructor: _isHonor ? _instructorRef(item) : null,
      revision: saving ? item.revision + 1 : item.revision,
    );
  }

  /// Keeps the row's own reference when nothing changed, so the caller can
  /// tell an untouched instructor from a new one.
  CertificateImportInstructorRef? _instructorRef(CertificateImportItem item) {
    if (_instructor == _initialInstructor) return item.instructor;
    return switch (_instructor.kind) {
      InstructorKind.none => null,
      InstructorKind.user => CertificateImportInstructorRef(
          isUser: true,
          userId: _instructor.userId,
          displayName: _instructor.displayName,
          photoUrl: _instructor.photoUrl,
        ),
      InstructorKind.external => CertificateImportInstructorRef(
          isUser: false,
          displayName: _instructor.displayName,
        ),
    };
  }

  static InstructorSelection _selectionOf(CertificateImportInstructorRef? ref) {
    if (ref == null) return const InstructorSelection.none();
    final id = ref.userId;
    return ref.isUser && id != null
        ? InstructorSelection.user(
            id: id,
            displayName: ref.displayName,
            photoUrl: ref.photoUrl,
          )
        : InstructorSelection.external(ref.displayName);
  }

  CertificateImportItem get _draft =>
      _make(CertificateImportItemStatus.needsReview);

  // ── pickers ────────────────────────────────────────────────────────────

  Future<void> _pickHonor() async {
    final honor = await HonorPickerSheet.show(
      context,
      initialQuery: _name.text.trim(),
      categoryId: _categoryId,
    );
    if (honor == null || !mounted) return;
    _touch(() {
      _honorId = honor.id;
      _honorClubTypeId = honor.clubTypeId;
      _honor = CertificateImportHonorRef(
        id: honor.id,
        name: honor.name,
        categoryId: honor.categoryId,
        categoryName: honor.categoryName,
      );
      _categoryId = honor.categoryId;
      _categoryName = honor.categoryName;
      _suggested = false;
      _honorError = null;
    });
  }

  Future<void> _pickCategory() async {
    final categories = ref.read(honorCategoriesProvider).valueOrNull ?? [];
    final choice = await showHonorCategoryPicker(
      context,
      categories: categories,
      selectedId: _categoryId,
    );
    if (choice == null || !mounted) return;
    final category = categories.where((c) => c.id == choice.id).firstOrNull;
    _touch(() {
      _categoryId = category?.id;
      _categoryName = category?.name;
      // A honor of another category no longer fits the filter.
      if (category != null &&
          _honor != null &&
          _honor!.categoryId != category.id) {
        _honorId = null;
        _honor = null;
        _honorError = 'certificate_import.editor.honor_category_mismatch'.tr(
          namedArgs: {'category': category.name},
        );
      }
    });
  }

  Future<void> _pickDate() async {
    final first = kMinCertificateDate;
    final last = CertificateDateRule.lastDate(_today);
    var initial = _date ?? last;
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      locale: context.locale,
    );
    if (picked == null || !mounted) return;
    _touch(() {
      _date = DateTime(picked.year, picked.month, picked.day);
      _dateError = null;
      _dateHint = ImportDateHint.none;
    });
  }

  void _setType(CertificateImportItemType type) {
    if (type == _type) return;
    // Keep the read text and the date; drop the other type's selection.
    _touch(() {
      _type = type;
      _honorError = _classError = null;
      // Only honors have an instructor: a class never sends one.
      if (type == CertificateImportItemType.clazz) {
        _instructor = const InstructorSelection.none();
        _instructorError = null;
      }
    });
  }

  // ── save ───────────────────────────────────────────────────────────────

  String _dateMessage(CertificateDateIssue issue) => switch (issue) {
        CertificateDateIssue.required =>
          'certificate_import.editor.date_required'.tr(),
        CertificateDateIssue.tooOld =>
          'certificate_import.errors.date_old.body'.tr(),
        CertificateDateIssue.future =>
          'certificate_import.errors.date_future.body'.tr(),
      };

  void _showFieldError(GlobalKey key, String message) {
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );
    final target = key.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        alignment: 0.1,
        duration:
            SacMotion.reduceMotionOf(context) ? Duration.zero : SacMotion.modal,
        curve: SacMotion.easeInOut,
      );
    }
  }

  Future<void> _save() async {
    final issue = CertificateDateRule.check(_date, now: _today);
    if (issue != null) {
      final message = _dateMessage(issue);
      setState(() => _dateError = message);
      _showFieldError(_dateKey, message);
      return;
    }
    setState(() {
      _saving = true;
      _classError = null;
      _banner = null;
      _bannerGoesToProfile = false;
    });
    final complete = _draft.isComplete;
    try {
      await widget.onSave(
        _make(
          complete
              ? CertificateImportItemStatus.ready
              : CertificateImportItemStatus.needsReview,
          saving: true,
        ),
      );
      if (!mounted) return;
      _dirty = false;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      // Keep the sheet open: field errors go on their field, the rest in the
      // banner, and nothing the member entered is lost.
      final kind = CertificateImportErrorMapper.kindOf(error);
      final info = CertificateImportErrorMapper.map(error);
      setState(() {
        _saving = false;
        switch (kind) {
          case CertificateImportErrorKind.dateTooOld:
          case CertificateImportErrorKind.dateInFuture:
          case CertificateImportErrorKind.dateInvalid:
          case CertificateImportErrorKind.dateRequired:
          case CertificateImportErrorKind.yearNotFound:
            _dateError = info.body;
          case CertificateImportErrorKind.classClubTypeMismatch:
          case CertificateImportErrorKind.classMinimumAgeRequired:
          case CertificateImportErrorKind.ageBelowMinimum:
            _classError = info.body;
          case CertificateImportErrorKind.birthdayRequired:
            // Nothing in this sheet fixes it: point to the profile.
            _banner = info.body;
            _bannerGoesToProfile =
                info.action == CertificateImportErrorAction.completeProfile;
          default:
            // HONOR_INSTRUCTOR_* belong on the instructor field.
            final code = error is Failure ? error.errorCode : null;
            final onField =
                _isHonor ? InstructorErrorCode.fieldMessage(code) : null;
            if (onField != null && code != InstructorErrorCode.ambiguous) {
              _instructorError = onField;
            } else {
              _banner = info.body;
            }
        }
      });
      final key = _dateError != null
          ? _dateKey
          : _classError != null
              ? _classKey
              : _instructorError != null
                  ? _instructorKey
                  : null;
      if (key != null) {
        _showFieldError(key, _dateError ?? _classError ?? _instructorError!);
      }
    }
  }

  Future<void> _openProfile() async {
    final open = widget.onOpenProfile;
    if (open != null) {
      open();
      return;
    }
    await Navigator.of(context).push<void>(
      SacSharedAxisRoute(builder: (_) => const EditProfileView()),
    );
    // Back from the profile: the member can save again.
    if (mounted) {
      setState(() {
        _banner = null;
        _bannerGoesToProfile = false;
      });
    }
  }

  Future<void> _confirmDiscard() async {
    final discard = await SacDialog.show(
      context,
      title: 'certificate_import.editor.discard_title'.tr(),
      confirmLabel: 'certificate_import.editor.discard_confirm'.tr(),
      cancelLabel: 'certificate_import.editor.discard_keep'.tr(),
      confirmIsDestructive: true,
    );
    if (discard == true && mounted) {
      _dirty = false;
      Navigator.of(context).pop();
    }
  }

  // ── build ──────────────────────────────────────────────────────────────

  String _missingLine(CertificateImportItem draft) {
    // The name fills itself from the catalog choice: only say it when it is
    // the one thing left.
    final missing = draft.missing.length > 1
        ? draft.missing.where((m) => m != CertificateImportMissing.name)
        : draft.missing;
    final names = missing.map(
      (m) => switch (m) {
        CertificateImportMissing.honor =>
          'certificate_import.editor.field_honor'.tr(),
        CertificateImportMissing.clazz =>
          'certificate_import.editor.field_class'.tr(),
        CertificateImportMissing.date =>
          'certificate_import.editor.field_date'.tr(),
        CertificateImportMissing.type =>
          'certificate_import.editor.field_type'.tr(),
        CertificateImportMissing.name =>
          'certificate_import.editor.field_name'.tr(),
      },
    );
    return 'certificate_import.editor.missing_line'.tr(
      namedArgs: {'fields': names.join(', ')},
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final item = widget.item;
    final draft = _draft;
    final reduce = SacMotion.reduceMotionOf(context);
    final title = widget.isNew
        ? 'certificate_import.editor.add_title'.tr()
        : (_isHonor
                ? 'certificate_import.editor.title_honor'
                : 'certificate_import.editor.title_class')
            .tr();
    final read = item.detectedName?.trim() ?? '';

    final fields = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_typeIsOpen) ...[
          Row(
            children: [
              for (final (type, key) in [
                (CertificateImportItemType.honor, 'honor'),
                (CertificateImportItemType.clazz, 'class'),
              ]) ...[
                SacFilterChip(
                  label: 'certificate_import.editor.$key'.tr(),
                  selected: _type == type,
                  onTap: () => _setType(type),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 8),
        ] else if (_isHonor)
          Align(
            alignment: Alignment.centerLeft,
            child: SacButton.ghost(
              text: 'certificate_import.editor.switch_to_class'.tr(),
              onPressed: () => _setType(CertificateImportItemType.clazz),
            ),
          ),
        if (_fixingText || widget.isNew || read.isEmpty)
          SacTextField(
            label: widget.isNew
                ? 'certificate_import.editor.manual_name'.tr()
                : 'certificate_import.editor.read_in_proof'.tr(),
            controller: _name,
            maxLength: 120,
            textInputAction: TextInputAction.next,
            onChanged: (_) => _touch(() {}),
          )
        else
          DetectedTextQuote(
            text: read,
            onViewProof: widget.onViewProof,
            proofLabel: widget.proofPage == null
                ? null
                : 'certificate_import.item.view_proof_page'.tr(
                    namedArgs: {'page': '${widget.proofPage}'},
                  ),
            onFix: () => setState(() => _fixingText = true),
          ),
        const SizedBox(height: 16),
        if (_isHonor) ..._honorFields() else ..._classFields(),
      ],
    );

    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SacSheetHeader(title: title, showClose: true),
              Flexible(
                child: SingleChildScrollView(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  // M17: notices and errors grow in without a jump.
                  child: reduce
                      ? fields
                      : AnimatedSize(
                          duration: SacMotion.standard,
                          curve: SacMotion.easeOut,
                          alignment: Alignment.topCenter,
                          child: fields,
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!draft.isComplete)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          _missingLine(draft),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: c.textSecondary),
                        ),
                      ),
                    ImportErrorBanner(
                      message: _banner,
                      actionLabel: _bannerGoesToProfile
                          ? 'certificate_import.errors.complete_profile'.tr()
                          : null,
                      onAction: _bannerGoesToProfile ? _openProfile : null,
                    ),
                    SacButton.primary(
                      text: 'certificate_import.editor.save'.tr(),
                      isLoading: _saving,
                      onPressed: _saving ? null : _save,
                    ),
                    if (widget.onRemove != null)
                      SacButton.ghost(
                        text: 'certificate_import.editor.remove'.tr(),
                        onPressed: _saving ? null : widget.onRemove,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _honorFields() {
    final categories = ref.watch(honorCategoriesProvider);
    // Adventurer honors have no categories (H14): hide the filter for them.
    final noCategories = _honor != null &&
        (isAdventurerHonorClubType(_honorClubTypeId) ||
            _honor!.categoryName == null);
    final name =
        _honor?.name ?? (_honorId != null ? widget.item.detectedName : null);
    return [
      if (categories.hasValue && !noCategories) ...[
        SacPickerField(
          label: 'certificate_import.editor.category'.tr(),
          hint: 'certificate_import.editor.category_hint'.tr(),
          icon: HugeIcons.strokeRoundedFolder01,
          selectedName: _categoryName,
          onTap: _pickCategory,
        ),
        const SizedBox(height: 16),
      ],
      KeyedSubtree(
        key: _honorKey,
        child: SacPickerField(
          label: 'certificate_import.editor.honor'.tr(),
          hint: 'certificate_import.editor.honor_hint'.tr(),
          icon: HugeIcons.strokeRoundedMedal05,
          selectedName: name,
          selectedSubtitle: _honor?.categoryName,
          leading: HonorBadgeImage(
            imageUrl: null,
            width: 28,
            height: 28,
            fallbackColor: context.sac.textSecondary,
            fallbackBackgroundColor: context.sac.surfaceVariant,
            fallbackIconSize: 16,
          ),
          badge: _suggested ? 'certificate_import.editor.suggested'.tr() : null,
          errorText: _honorError,
          onTap: _pickHonor,
        ),
      ),
      const SizedBox(height: 16),
      KeyedSubtree(key: _dateKey, child: _dateField(honor: true)),
      const SizedBox(height: 16),
      KeyedSubtree(
        key: _instructorKey,
        child: InstructorField(
          selection: _instructor,
          errorText: _instructorError,
          onChanged: (value) => _touch(() {
            _instructor = value;
            _instructorError = null;
          }),
        ),
      ),
      const SizedBox(height: 16),
    ];
  }

  List<Widget> _classFields() {
    return [
      KeyedSubtree(
        key: _classKey,
        child: ImportClassSection(
          clubTypeId: _clubTypeId,
          classId: _class?.id ?? _classId,
          classError: _classError,
          suggested: _suggested,
          onClubType: (id) => _touch(() {
            if (id == _clubTypeId) return;
            _clubTypeId = id;
            _class = null;
            _classId = null;
            _classError = null;
          }),
          onClass: (option) => _touch(() {
            _class = option;
            _classId = option.id;
            _suggested = false;
            _classError = null;
          }),
        ),
      ),
      const SizedBox(height: 16),
      _dateField(honor: false),
      const SizedBox(height: 16),
    ];
  }

  Widget _dateField({required bool honor}) => ImportDateField(
        label: (honor
                ? 'certificate_import.editor.date_honor'
                : 'certificate_import.editor.date_class')
            .tr(),
        value: _date,
        errorText: _dateError,
        hint: _dateHint,
        onTap: _pickDate,
      );
}

/// Opens the editor in a sheet capped at 92 % of the screen.
Future<void> showCertificateImportItemEditor(
  BuildContext context, {
  required CertificateImportItem item,
  required Future<void> Function(CertificateImportItem item) onSave,
  VoidCallback? onRemove,
  VoidCallback? onViewProof,
  int? proofPage,
  bool isNew = false,
}) {
  return showSacSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => CertificateImportItemEditorSheet(
      item: item,
      onSave: onSave,
      onRemove: onRemove,
      onViewProof: onViewProof,
      proofPage: proofPage,
      isNew: isNew,
    ),
  );
}
