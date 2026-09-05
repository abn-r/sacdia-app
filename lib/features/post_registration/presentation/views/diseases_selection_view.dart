import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_text_field.dart';
import 'package:sacdia_app/core/widgets/fixed_input_icon_slot.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';
import '../../../../core/utils/app_logger.dart';
import '../../data/models/disease_model.dart';
import '../providers/personal_info_providers.dart';
import '../../../profile/presentation/widgets/medico/medico_tokens.dart';
import '../../../profile/presentation/widgets/medico/medico_section_card.dart';
import '../../../profile/presentation/widgets/medico/medical_chip.dart';
import '../utils/health_selection_state.dart';

/// Redesigned view for managing user diseases.
/// Amber tone. Inline year editor. None toggle above search.
class DiseasesSelectionView extends ConsumerStatefulWidget {
  const DiseasesSelectionView({super.key});

  @override
  ConsumerState<DiseasesSelectionView> createState() =>
      _DiseasesSelectionViewState();
}

class _DiseasesSelectionViewState extends ConsumerState<DiseasesSelectionView> {
  // ── Server state ─────────────────────────────────────────────────────────
  Set<int> _serverIds = {};
  bool _serverSeeded = false;
  final Map<int, int?> _serverYearMap = {};
  final Map<int, int?> _modifiedRegistered = {};

  // ── Pending new ──────────────────────────────────────────────────────────
  final Set<int> _selectedIds = {};
  final Map<int, int?> _pendingYearMap = {};

  // ── UI state ─────────────────────────────────────────────────────────────
  int? _expandedAvailableId;
  int? _expandedRegisteredId;
  bool _noneExplicit = false;
  bool _isSaving = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Map<int, GlobalKey> _tileKeys = {};

  // TextControllers for year inputs (available)
  final Map<int, TextEditingController> _availableYearControllers = {};
  // TextControllers for year inputs (registered)
  final Map<int, TextEditingController> _registeredYearControllers = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(userDiseasesProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (final c in _availableYearControllers.values) {
      c.dispose();
    }
    for (final c in _registeredYearControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Seeding ──────────────────────────────────────────────────────────────

  void _seedFromServer(List<DiseaseModel> items) {
    if (_serverSeeded) return;
    _serverSeeded = true;
    _serverIds = items.map((d) => d.id).toSet();
    for (final d in items) {
      _serverYearMap[d.id] = d.sinceYear;
    }
  }

  void _hydrateSavedNone(bool savedNone) {
    if (!savedNone ||
        _serverIds.isNotEmpty ||
        _noneExplicit ||
        _selectedIds.isNotEmpty ||
        _modifiedRegistered.isNotEmpty) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !savedNone ||
          _serverIds.isNotEmpty ||
          _noneExplicit ||
          _selectedIds.isNotEmpty ||
          _modifiedRegistered.isNotEmpty) {
        return;
      }
      setState(() => _noneExplicit = true);
    });
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  int? _yearFor(int id) => _pendingYearMap[id];
  int? _registeredYearFor(int id) => _modifiedRegistered.containsKey(id)
      ? _modifiedRegistered[id]
      : _serverYearMap[id];

  bool get _hasPendingChanges {
    return hasHealthSelectionPendingChanges(
      noneExplicit: _noneExplicit,
      hasNewSelections: _selectedIds.isNotEmpty,
      hasModifiedRegistered: _modifiedRegistered.isNotEmpty,
    );
  }

  int get _pendingCount => _selectedIds.length + _modifiedRegistered.length;

  TextEditingController _availableControllerFor(int id) {
    return _availableYearControllers.putIfAbsent(
      id,
      () => TextEditingController(text: _pendingYearMap[id]?.toString() ?? ''),
    );
  }

  TextEditingController _registeredControllerFor(int id) {
    return _registeredYearControllers.putIfAbsent(
      id,
      () => TextEditingController(
          text: (_registeredYearFor(id))?.toString() ?? ''),
    );
  }

  // ── None toggle ───────────────────────────────────────────────────────────

  Future<void> _handleNoneToggle(BuildContext context) async {
    if (_noneExplicit) {
      setState(() => _noneExplicit = false);
      return;
    }

    if (_selectedIds.isNotEmpty) {
      final confirmed = await SacDialog.show(
        context,
        title:
            'post_registration.health.diseases.no_diseases_confirm_title'.tr(),
        content: 'post_registration.health.diseases.no_diseases_confirm_content'
            .tr(),
        confirmLabel: 'common.confirm'.tr(),
      );
      if (confirmed != true) return;
      setState(() {
        _selectedIds.clear();
        _pendingYearMap.clear();
        _expandedAvailableId = null;
        _noneExplicit = true;
      });
      return;
    }

    if (_serverIds.isNotEmpty) {
      final count = _serverIds.length;
      final confirmed = await SacDialog.show(
        context,
        title:
            'post_registration.health.diseases.no_diseases_confirm_title'.tr(),
        content:
            'post_registration.health.diseases.no_diseases_destructive_content'
                .tr(namedArgs: {'count': '$count'}),
        confirmLabel: 'common.confirm'.tr(),
        confirmIsDestructive: true,
      );
      if (confirmed != true) return;
    }

    setState(() {
      _selectedIds.clear();
      _pendingYearMap.clear();
      _expandedAvailableId = null;
      _noneExplicit = true;
    });
  }

  // ── Available list ────────────────────────────────────────────────────────

  void _handleAvailableTap(int id) {
    if (_noneExplicit) {
      if (_serverIds.isEmpty) setState(() => _noneExplicit = false);
      return;
    }

    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        _pendingYearMap.remove(id);
        _availableYearControllers[id]?.dispose();
        _availableYearControllers.remove(id);
        if (_expandedAvailableId == id) _expandedAvailableId = null;
      } else {
        _selectedIds.add(id);
        _expandedAvailableId = id;
      }
    });

    if (_selectedIds.contains(id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final key = _tileKeys[id];
        if (key?.currentContext != null) {
          Scrollable.ensureVisible(
            key!.currentContext!,
            alignment: 0.1,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _removeAvailable(int id) {
    setState(() {
      _selectedIds.remove(id);
      _pendingYearMap.remove(id);
      _availableYearControllers[id]?.dispose();
      _availableYearControllers.remove(id);
      if (_expandedAvailableId == id) _expandedAvailableId = null;
    });
  }

  // ── Registered ────────────────────────────────────────────────────────────

  void _handleRegisteredChipTap(int id) {
    setState(() {
      _expandedRegisteredId = _expandedRegisteredId == id ? null : id;
    });
  }

  Future<void> _handleRegisteredLongPress(
    BuildContext context,
    int id,
    String name,
  ) async {
    final m = MedicoTokens.of(context);
    await showSacSheet<void>(
      context: context,
      backgroundColor: m.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: HugeIcon(
                    icon: HugeIcons.strokeRoundedEdit02,
                    size: 22,
                    color: m.iconStrong,
                  ),
                  title: Text(
                    'post_registration.health.diseases.edit_chip_a11y'.tr(),
                    style: TextStyle(color: m.textPrimary),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    setState(() => _expandedRegisteredId = id);
                  },
                ),
                ListTile(
                  leading: const HugeIcon(
                    icon: HugeIcons.strokeRoundedDelete02,
                    size: 22,
                    color: MedicoTokens.coral600,
                  ),
                  title: Text(
                    'post_registration.health.diseases.remove_selection'.tr(),
                    style: const TextStyle(color: MedicoTokens.coral600),
                  ),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await _showDeleteConfirmation(context, id, name);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDeleteConfirmation(
    BuildContext context,
    int diseaseId,
    String diseaseName,
  ) async {
    final confirmed = await SacDialog.show(
      context,
      title: 'post_registration.health.diseases.delete_dialog_title'.tr(),
      content: 'post_registration.health.diseases.delete_dialog_content'
          .tr(namedArgs: {'name': diseaseName}),
      confirmLabel: 'common.delete'.tr(),
      confirmIsDestructive: true,
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(userDiseasesProvider.notifier).deleteDisease(diseaseId);
        setState(() {
          _serverIds.remove(diseaseId);
          _serverYearMap.remove(diseaseId);
          _modifiedRegistered.remove(diseaseId);
          _registeredYearControllers[diseaseId]?.dispose();
          _registeredYearControllers.remove(diseaseId);
          if (_expandedRegisteredId == diseaseId) _expandedRegisteredId = null;
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('post_registration.health.diseases.delete_success'.tr()),
              backgroundColor: MedicoTokens.mint500,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } catch (e) {
        AppLogger.e('Delete disease error', tag: 'DiseasesView', error: e);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'post_registration.health.diseases.delete_error'
                    .tr(namedArgs: {'error': e.toString()}),
              ),
              backgroundColor: MedicoTokens.coral600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    }
  }

  // ── Pull-to-refresh ───────────────────────────────────────────────────────

  Future<void> _onRefresh() async {
    setState(() => _serverSeeded = false);
    await ref.read(userDiseasesProvider.notifier).refresh();
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save(BuildContext context) async {
    if (_isSaving || !_hasPendingChanges) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final List<DiseaseEntry> entries = [];

      if (!_noneExplicit) {
        for (final id in _serverIds) {
          entries.add(DiseaseEntry(id: id, sinceYear: _registeredYearFor(id)));
        }
        for (final id in _selectedIds) {
          entries.add(DiseaseEntry(id: id, sinceYear: _yearFor(id)));
        }
      }

      await ref.read(userDiseasesProvider.notifier).saveAll(entries);

      final updated = ref.read(userDiseasesProvider).valueOrNull ?? [];
      ref.read(selectedDiseasesProvider.notifier).state =
          updated.map((d) => d.id).toList();
      setState(() {
        _serverSeeded = false;
        _selectedIds.clear();
        _pendingYearMap.clear();
        _modifiedRegistered.clear();
        _expandedAvailableId = null;
        _expandedRegisteredId = null;
        _isSaving = false;
        _noneExplicit = false;
        // clear controllers
        for (final c in _availableYearControllers.values) {
          c.dispose();
        }
        _availableYearControllers.clear();
        for (final c in _registeredYearControllers.values) {
          c.dispose();
        }
        _registeredYearControllers.clear();
      });
      _seedFromServer(updated);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('common.save'.tr()),
            backgroundColor: MedicoTokens.mint500,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 300));
        if (context.mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      AppLogger.e('Save diseases error', tag: 'DiseasesView', error: e);
      setState(() => _isSaving = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('common.save_error_retry'.tr()),
            backgroundColor: MedicoTokens.coral600,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            action: SnackBarAction(
              label: 'common.retry'.tr(),
              textColor: Colors.white,
              onPressed: () => _save(context),
            ),
          ),
        );
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<DiseaseModel>>>(
      userDiseasesProvider,
      (prev, next) {
        if (next.value != null && !_serverSeeded) {
          _seedFromServer(next.value!);
          ref.read(selectedDiseasesProvider.notifier).state =
              next.value!.map((d) => d.id).toList();
        }
      },
    );

    final catalogAsync = ref.watch(diseasesCatalogProvider);
    final userAsync = ref.watch(userDiseasesProvider);
    final savedNone =
        ref.watch(healthNoneStateProvider).valueOrNull?.diseases ?? false;
    _hydrateSavedNone(savedNone);
    final m = MedicoTokens.of(context);

    return Scaffold(
      backgroundColor: m.canvas,
      appBar: AppBar(
        backgroundColor: m.paper,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'post_registration.health.diseases.title'.tr(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: m.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            size: 24,
            color: m.iconStrong,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: m.border),
        ),
      ),
      body: catalogAsync.when(
        loading: () => const Center(child: SacLoading()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const HugeIcon(
                  icon: HugeIcons.strokeRoundedAlert02,
                  size: 48,
                  color: MedicoTokens.coral600,
                ),
                const SizedBox(height: 16),
                Text(
                  'post_registration.health.diseases.load_error'
                      .tr(namedArgs: {'error': error.toString()}),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                SacButton(
                  text: 'common.retry'.tr(),
                  icon: HugeIcons.strokeRoundedRefresh,
                  variant: SacButtonVariant.primary,
                  fullWidth: false,
                  backgroundColor: MedicoTokens.coral500,
                  textColor: Colors.white,
                  onPressed: () => ref.refresh(diseasesCatalogProvider),
                ),
              ],
            ),
          ),
        ),
        data: (catalog) {
          final serverItems = userAsync.valueOrNull ?? [];
          if (!_serverSeeded && serverItems.isNotEmpty) {
            _seedFromServer(serverItems);
          }

          final available = catalog
              .where((d) => !_serverIds.contains(d.id))
              .where((d) =>
                  _searchQuery.isEmpty ||
                  d.name.toLowerCase().contains(_searchQuery.toLowerCase()))
              .toList();

          return Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  color: MedicoTokens.coral500,
                  onRefresh: _onRefresh,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Info banner (amber)
                              _InfoBanner(
                                text:
                                    'post_registration.health.diseases.info_text'
                                        .tr(),
                                bgColor: m.amberSoft,
                                fgColor: m.amberInk,
                                iconWidget: HugeIcon(
                                  icon: HugeIcons.strokeRoundedHealth,
                                  size: 16,
                                  color: m.amberFg,
                                ),
                              ),

                              const SizedBox(height: 12),

                              // Ya registradas
                              if (userAsync.isLoading)
                                const Center(child: SacLoading())
                              else if (_serverIds.isNotEmpty) ...[
                                MedicoSectionCard(
                                  dense: true,
                                  iconWidget: HugeIcon(
                                    icon: HugeIcons.strokeRoundedHealth,
                                    size: 20,
                                    color: m.amberFg,
                                  ),
                                  iconBg: m.amberSoft,
                                  title: _serverIds.length == 1
                                      ? 'post_registration.health.diseases.registered_count_one'
                                          .tr()
                                      : 'post_registration.health.diseases.registered_count'
                                          .tr(namedArgs: {
                                          'count': '${_serverIds.length}'
                                        }),
                                  child: _RegisteredDiseasesSection(
                                    serverItems: serverItems,
                                    expandedId: _expandedRegisteredId,
                                    modifiedMap: _modifiedRegistered,
                                    onChipTap: _handleRegisteredChipTap,
                                    onChipLongPress: (id, name) =>
                                        _handleRegisteredLongPress(
                                            context, id, name),
                                    onYearChange: (id, year) {
                                      setState(
                                          () => _modifiedRegistered[id] = year);
                                    },
                                    onRemove: (id, name) =>
                                        _showDeleteConfirmation(
                                            context, id, name),
                                    registeredYearFor: _registeredYearFor,
                                    controllerFor: _registeredControllerFor,
                                  ),
                                ),
                              ],

                              const SizedBox(height: 14),

                              // "Agregar nuevas"
                              Text(
                                'post_registration.health.diseases.add_new_section'
                                    .tr(),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: m.iconMuted,
                                ),
                              ),

                              const SizedBox(height: 8),

                              // Search bar
                              TextField(
                                controller: _searchController,
                                onChanged: (v) =>
                                    setState(() => _searchQuery = v),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: m.textPrimary,
                                ),
                                decoration: InputDecoration(
                                  hintText:
                                      'post_registration.health.diseases.search_hint'
                                          .tr(),
                                  hintStyle: TextStyle(
                                      color: m.textSecondary, fontSize: 15),
                                  prefixIconConstraints:
                                      FixedInputIconSlot.constraints,
                                  prefixIcon: FixedInputIconSlot(
                                    icon: HugeIcons.strokeRoundedSearch01,
                                    iconSize: 22,
                                    color: m.textSecondary,
                                  ),
                                  suffixIcon: _searchQuery.isNotEmpty
                                      ? IconButton(
                                          icon: HugeIcon(
                                            icon:
                                                HugeIcons.strokeRoundedCancel01,
                                            size: 20,
                                            color: m.textSecondary,
                                          ),
                                          onPressed: () => setState(() {
                                            _searchController.clear();
                                            _searchQuery = '';
                                          }),
                                        )
                                      : null,
                                  filled: true,
                                  fillColor: m.controlBg,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: MedicoTokens.coral500,
                                        width: 1.5),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),

                              // None toggle
                              _NoneToggleCard(
                                isActive: _noneExplicit,
                                label:
                                    'post_registration.health.diseases.no_diseases_toggle_label'
                                        .tr(),
                                helper:
                                    'post_registration.health.diseases.no_diseases_toggle_helper'
                                        .tr(),
                                onTap: () => _handleNoneToggle(context),
                              ),

                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ),

                      // Available list
                      if (_noneExplicit)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            child: Opacity(
                              opacity: 0.4,
                              child: IgnorePointer(
                                child: Text(
                                  'post_registration.health.diseases.none_active_caption'
                                      .tr(),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: m.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                      else if (available.isEmpty && _searchQuery.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 48),
                            child: Column(
                              children: [
                                HugeIcon(
                                  icon: HugeIcons.strokeRoundedSearchMinus,
                                  size: 64,
                                  color: m.iconMuted.withValues(alpha: 0.6),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'common.no_results'.tr(),
                                  style: TextStyle(color: m.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              if (index >= available.length) return null;
                              final item = available[index];
                              final isSelected = _selectedIds.contains(item.id);
                              final isExpanded =
                                  _expandedAvailableId == item.id;

                              _tileKeys[item.id] ??= GlobalKey();

                              return _DiseaseTile(
                                key: ValueKey(item.id),
                                tileKey: _tileKeys[item.id]!,
                                name: item.name,
                                isSelected: isSelected,
                                isExpanded: isExpanded,
                                controller: isSelected
                                    ? _availableControllerFor(item.id)
                                    : null,
                                onTap: () => _handleAvailableTap(item.id),
                                onYearChanged: (year) {
                                  setState(
                                      () => _pendingYearMap[item.id] = year);
                                },
                                onRemove: () => _removeAvailable(item.id),
                              );
                            },
                            childCount: available.length,
                          ),
                        ),

                      const SliverToBoxAdapter(child: SizedBox(height: 8)),
                    ],
                  ),
                ),
              ),

              // Sticky footer
              _StickyFooter(
                registeredCount: _serverIds.length,
                pendingCount: _pendingCount,
                isSaving: _isSaving,
                canSave: _hasPendingChanges,
                onSave: () => _save(context),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Registered diseases section
// ─────────────────────────────────────────────────────────────────────────────

class _RegisteredDiseasesSection extends StatelessWidget {
  final List<DiseaseModel> serverItems;
  final int? expandedId;
  final Map<int, int?> modifiedMap;
  final void Function(int id) onChipTap;
  final void Function(int id, String name) onChipLongPress;
  final void Function(int id, int? year) onYearChange;
  final void Function(int id, String name) onRemove;
  final int? Function(int) registeredYearFor;
  final TextEditingController Function(int) controllerFor;

  const _RegisteredDiseasesSection({
    required this.serverItems,
    required this.expandedId,
    required this.modifiedMap,
    required this.onChipTap,
    required this.onChipLongPress,
    required this.onYearChange,
    required this.onRemove,
    required this.registeredYearFor,
    required this.controllerFor,
  });

  @override
  Widget build(BuildContext context) {
    DiseaseModel? expandedItem;
    for (final item in serverItems) {
      if (item.id == expandedId) {
        expandedItem = item;
        break;
      }
    }
    final expanded = expandedItem;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: serverItems.map((item) {
            final year = registeredYearFor(item.id);

            return GestureDetector(
              onTap: () => onChipTap(item.id),
              onLongPress: () => onChipLongPress(item.id, item.name),
              child: Semantics(
                label:
                    '${item.name}${year != null ? ', $year' : ''}, ${tr('post_registration.health.diseases.edit_chip_a11y')}',
                button: true,
                child: MedicalChip(
                  label: item.name,
                  tone: SeverityTone.amber,
                  sub: year != null ? '$year' : null,
                ),
              ),
            );
          }).toList(),
        ),
        if (expanded != null) ...[
          const SizedBox(height: 8),
          _YearEditor(
            controller: controllerFor(expanded.id),
            onChanged: (y) => onYearChange(expanded.id, y),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Disease available tile
// ─────────────────────────────────────────────────────────────────────────────

class _DiseaseTile extends StatelessWidget {
  final Key tileKey;
  final String name;
  final bool isSelected;
  final bool isExpanded;
  final TextEditingController? controller;
  final VoidCallback onTap;
  final ValueChanged<int?> onYearChanged;
  final VoidCallback onRemove;

  const _DiseaseTile({
    super.key,
    required this.tileKey,
    required this.name,
    required this.isSelected,
    required this.isExpanded,
    required this.controller,
    required this.onTap,
    required this.onYearChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final m = MedicoTokens.of(context);
    return Container(
      key: tileKey,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
      decoration: BoxDecoration(
        color: isSelected ? m.amberSoft : m.paper,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: isSelected
              ? BorderSide(color: m.amberFg, width: 3)
              : BorderSide.none,
        ),
      ),
      child: AnimatedSize(
        duration: SacMotion.reduceMotionOf(context)
            ? Duration.zero
            : SacMotion.standard,
        curve: SacMotion.easeInOut,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: m.textPrimary,
                        ),
                      ),
                    ),
                    if (isSelected)
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedTick02,
                        size: 20,
                        color: m.amberFg,
                      ),
                  ],
                ),
              ),
            ),
            if (isExpanded && controller != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _YearEditor(
                      controller: controller!,
                      onChanged: onYearChanged,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: onRemove,
                      style: TextButton.styleFrom(
                        foregroundColor: m.iconMuted,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'post_registration.health.diseases.remove_selection'
                            .tr(),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Year editor
// ─────────────────────────────────────────────────────────────────────────────

class _YearEditor extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<int?> onChanged;

  const _YearEditor({
    required this.controller,
    required this.onChanged,
  });

  void _validate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      onChanged(null);
      return;
    }
    final year = int.tryParse(trimmed);
    final currentYear = DateTime.now().year;
    if (year == null || year < 1900 || year > currentYear) {
      onChanged(null);
    } else {
      onChanged(year);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = MedicoTokens.of(context);
    return SacTextField(
      controller: controller,
      label: 'post_registration.diseases.since_year_label'.tr(),
      hint: 'post_registration.diseases.since_year_hint'.tr(),
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(4),
      ],
      suffix: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Text(
          'post_registration.health.diseases.year_suffix'.tr(),
          style: TextStyle(fontSize: 13, color: m.textSecondary),
        ),
      ),
      validator: (value) {
        final trimmed = value?.trim() ?? '';
        if (trimmed.isEmpty) return null;
        final year = int.tryParse(trimmed);
        final currentYear = DateTime.now().year;
        if (year == null || year < 1900 || year > currentYear) {
          return 'post_registration.diseases.since_year_invalid'.tr();
        }
        return null;
      },
      onChanged: _validate,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info banner
// ─────────────────────────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  final String text;
  final Color bgColor;
  final Color fgColor;
  final Widget iconWidget;

  const _InfoBanner({
    required this.text,
    required this.bgColor,
    required this.fgColor,
    required this.iconWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          iconWidget,
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: fgColor,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// None toggle card
// ─────────────────────────────────────────────────────────────────────────────

class _NoneToggleCard extends StatelessWidget {
  final bool isActive;
  final String label;
  final String helper;
  final VoidCallback onTap;

  const _NoneToggleCard({
    required this.isActive,
    required this.label,
    required this.helper,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final m = MedicoTokens.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isActive ? m.mintSoft : m.paper,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? m.mintFg : m.border,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: m.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    helper,
                    style: TextStyle(
                      fontSize: 12,
                      color: m.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: isActive,
              onChanged: (_) => onTap(),
              activeThumbColor: m.paper,
              activeTrackColor: m.mintInk,
              inactiveThumbColor: m.paper,
              inactiveTrackColor: m.iconMuted.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sticky footer
// ─────────────────────────────────────────────────────────────────────────────

class _StickyFooter extends StatelessWidget {
  final int registeredCount;
  final int pendingCount;
  final bool isSaving;
  final bool canSave;
  final VoidCallback onSave;

  const _StickyFooter({
    required this.registeredCount,
    required this.pendingCount,
    required this.isSaving,
    required this.canSave,
    required this.onSave,
  });

  String _counterText() {
    if (pendingCount == 0) {
      return 'common.no_pending_changes'
          .tr(namedArgs: {'count': '$registeredCount'});
    }
    if (pendingCount == 1) {
      return 'common.pending_changes_one'
          .tr(namedArgs: {'registered': '$registeredCount'});
    }
    return 'common.pending_changes_other'.tr(namedArgs: {
      'registered': '$registeredCount',
      'pending': '$pendingCount',
    });
  }

  @override
  Widget build(BuildContext context) {
    final m = MedicoTokens.of(context);
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: 12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: m.paper,
        border: Border(top: BorderSide(color: m.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _counterText(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: m.iconMuted,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SacButton(
            text: 'common.save'.tr(),
            variant: SacButtonVariant.primary,
            fullWidth: false,
            isLoading: isSaving,
            backgroundColor: MedicoTokens.coral500,
            textColor: Colors.white,
            onPressed: canSave && !isSaving ? onSave : null,
          ),
        ],
      ),
    );
  }
}
