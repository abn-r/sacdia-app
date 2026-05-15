import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import '../../../../core/utils/app_logger.dart';
import '../../data/models/medicine_model.dart';
import '../providers/personal_info_providers.dart';
import '../../../profile/presentation/widgets/medico/medico_tokens.dart';
import '../../../profile/presentation/widgets/medico/medico_section_card.dart';
import '../../../profile/presentation/widgets/medico/medical_chip.dart';
import '../../../profile/presentation/widgets/medico/empty_hint.dart';

/// Redesigned view for managing user medicines.
/// Mint tone. Inline dose editor. None toggle above search.
class MedicinesSelectionView extends ConsumerStatefulWidget {
  const MedicinesSelectionView({super.key});

  @override
  ConsumerState<MedicinesSelectionView> createState() =>
      _MedicinesSelectionViewState();
}

class _MedicinesSelectionViewState
    extends ConsumerState<MedicinesSelectionView> {
  // ── Server state ─────────────────────────────────────────────────────────
  Set<int> _serverIds = {};
  bool _serverSeeded = false;
  final Map<int, String?> _serverDoseMap = {};
  final Map<int, String?> _modifiedRegistered = {};

  // ── Pending new ──────────────────────────────────────────────────────────
  final Set<int> _selectedIds = {};
  final Map<int, String?> _pendingDoseMap = {};

  // ── UI state ─────────────────────────────────────────────────────────────
  int? _expandedAvailableId;
  int? _expandedRegisteredId;
  bool _noneExplicit = false;
  bool _isSaving = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Map<int, GlobalKey> _tileKeys = {};

  final Map<int, TextEditingController> _availableDoseControllers = {};
  final Map<int, TextEditingController> _registeredDoseControllers = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(userMedicinesProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (final c in _availableDoseControllers.values) {
      c.dispose();
    }
    for (final c in _registeredDoseControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Seeding ──────────────────────────────────────────────────────────────

  void _seedFromServer(List<MedicineModel> items) {
    if (_serverSeeded) return;
    _serverSeeded = true;
    _serverIds = items.map((m) => m.id).toSet();
    for (final m in items) {
      _serverDoseMap[m.id] = m.dose;
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String? _doseFor(int id) => _pendingDoseMap[id];
  String? _registeredDoseFor(int id) => _modifiedRegistered.containsKey(id)
      ? _modifiedRegistered[id]
      : _serverDoseMap[id];

  bool get _hasPendingChanges {
    if (_selectedIds.isNotEmpty) return true;
    if (_modifiedRegistered.isNotEmpty) return true;
    if (_noneExplicit && _serverIds.isNotEmpty) return true;
    return false;
  }

  int get _pendingCount => _selectedIds.length + _modifiedRegistered.length;

  TextEditingController _availableControllerFor(int id) {
    return _availableDoseControllers.putIfAbsent(
      id,
      () => TextEditingController(text: _pendingDoseMap[id] ?? ''),
    );
  }

  TextEditingController _registeredControllerFor(int id) {
    return _registeredDoseControllers.putIfAbsent(
      id,
      () => TextEditingController(text: _registeredDoseFor(id) ?? ''),
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
        title: 'post_registration.health.medicines.no_medicines_confirm_title'
            .tr(),
        content:
            'post_registration.health.medicines.no_medicines_confirm_content'
                .tr(),
        confirmLabel: 'common.confirm'.tr(),
      );
      if (confirmed != true) return;
      setState(() {
        _selectedIds.clear();
        _pendingDoseMap.clear();
        _expandedAvailableId = null;
        _noneExplicit = true;
      });
      return;
    }

    if (_serverIds.isNotEmpty) {
      final count = _serverIds.length;
      final confirmed = await SacDialog.show(
        context,
        title: 'post_registration.health.medicines.no_medicines_confirm_title'
            .tr(),
        content:
            'post_registration.health.medicines.no_medicines_destructive_content'
                .tr(namedArgs: {'count': '$count'}),
        confirmLabel: 'common.confirm'.tr(),
        confirmIsDestructive: true,
      );
      if (confirmed != true) return;
    }

    setState(() {
      _selectedIds.clear();
      _pendingDoseMap.clear();
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
        _pendingDoseMap.remove(id);
        _availableDoseControllers[id]?.dispose();
        _availableDoseControllers.remove(id);
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
      _pendingDoseMap.remove(id);
      _availableDoseControllers[id]?.dispose();
      _availableDoseControllers.remove(id);
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
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: MedicoTokens.paper,
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
                  leading: const HugeIcon(
                    icon: HugeIcons.strokeRoundedEdit02,
                    size: 22,
                    color: MedicoTokens.ink700,
                  ),
                  title: Text(
                    'post_registration.health.medicines.edit_chip_a11y'.tr(),
                    style: const TextStyle(color: MedicoTokens.ink900),
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
                    'post_registration.health.medicines.remove_selection'.tr(),
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
    int medicineId,
    String medicineName,
  ) async {
    final confirmed = await SacDialog.show(
      context,
      title: 'post_registration.health.medicines.delete_dialog_title'.tr(),
      content: 'post_registration.health.medicines.delete_dialog_content'
          .tr(namedArgs: {'name': medicineName}),
      confirmLabel: 'common.delete'.tr(),
      confirmIsDestructive: true,
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref
            .read(userMedicinesProvider.notifier)
            .deleteMedicine(medicineId);
        setState(() {
          _serverIds.remove(medicineId);
          _serverDoseMap.remove(medicineId);
          _modifiedRegistered.remove(medicineId);
          _registeredDoseControllers[medicineId]?.dispose();
          _registeredDoseControllers.remove(medicineId);
          if (_expandedRegisteredId == medicineId) _expandedRegisteredId = null;
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'post_registration.health.medicines.delete_success'.tr()),
              backgroundColor: MedicoTokens.mint500,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } catch (e) {
        AppLogger.e('Delete medicine error', tag: 'MedicinesView', error: e);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'post_registration.health.medicines.delete_error'
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
    await ref.read(userMedicinesProvider.notifier).refresh();
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save(BuildContext context) async {
    if (_isSaving || !_hasPendingChanges) return;

    setState(() => _isSaving = true);

    try {
      final List<MedicineEntry> entries = [];

      if (!_noneExplicit) {
        for (final id in _serverIds) {
          entries.add(MedicineEntry(id: id, dose: _registeredDoseFor(id)));
        }
        for (final id in _selectedIds) {
          entries.add(MedicineEntry(id: id, dose: _doseFor(id)));
        }
      }

      await ref.read(userMedicinesProvider.notifier).saveAll(entries);

      final updated = ref.read(userMedicinesProvider).valueOrNull ?? [];
      setState(() {
        _serverSeeded = false;
        _selectedIds.clear();
        _pendingDoseMap.clear();
        _modifiedRegistered.clear();
        _expandedAvailableId = null;
        _expandedRegisteredId = null;
        _isSaving = false;
        _noneExplicit = false;
        for (final c in _availableDoseControllers.values) {
          c.dispose();
        }
        _availableDoseControllers.clear();
        for (final c in _registeredDoseControllers.values) {
          c.dispose();
        }
        _registeredDoseControllers.clear();
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
      AppLogger.e('Save medicines error', tag: 'MedicinesView', error: e);
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
              textColor: MedicoTokens.paper,
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
    ref.listen<AsyncValue<List<MedicineModel>>>(
      userMedicinesProvider,
      (prev, next) {
        if (next.value != null && !_serverSeeded) {
          _seedFromServer(next.value!);
          ref.read(selectedMedicinesProvider.notifier).state =
              next.value!.map((m) => m.id).toList();
        }
      },
    );

    final catalogAsync = ref.watch(medicinesCatalogProvider);
    final userAsync = ref.watch(userMedicinesProvider);

    return Scaffold(
      backgroundColor: MedicoTokens.canvas,
      appBar: AppBar(
        backgroundColor: MedicoTokens.paper,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'post_registration.health.medicines.title'.tr(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: MedicoTokens.ink900,
          ),
        ),
        leading: IconButton(
          icon: const HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            size: 24,
            color: MedicoTokens.ink700,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: MedicoTokens.ink150),
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
                  'post_registration.health.medicines.load_error'
                      .tr(namedArgs: {'error': error.toString()}),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => ref.refresh(medicinesCatalogProvider),
                  style: FilledButton.styleFrom(
                      backgroundColor: MedicoTokens.coral500),
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedRefresh,
                    size: 20,
                    color: MedicoTokens.paper,
                  ),
                  label: Text('common.retry'.tr()),
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
              .where((m) => !_serverIds.contains(m.id))
              .where((m) =>
                  _searchQuery.isEmpty ||
                  m.name.toLowerCase().contains(_searchQuery.toLowerCase()))
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
                              // Info banner (mint)
                              _InfoBanner(
                                text:
                                    'post_registration.health.medicines.info_text'
                                        .tr(),
                                bgColor: MedicoTokens.mint50,
                                fgColor: MedicoTokens.mintInk,
                                iconWidget: const HugeIcon(
                                  icon: HugeIcons.strokeRoundedMedicine01,
                                  size: 20,
                                  color: MedicoTokens.mint500,
                                ),
                              ),

                              const SizedBox(height: 20),

                              // Ya registrados
                              if (userAsync.isLoading)
                                const Center(child: SacLoading())
                              else if (_serverIds.isNotEmpty) ...[
                                MedicoSectionCard(
                                  iconWidget: const HugeIcon(
                                    icon: HugeIcons.strokeRoundedMedicine01,
                                    size: 20,
                                    color: MedicoTokens.mint500,
                                  ),
                                  iconBg: MedicoTokens.mint50,
                                  title: _serverIds.length == 1
                                      ? 'post_registration.health.medicines.registered_count_one'
                                          .tr()
                                      : 'post_registration.health.medicines.registered_count'
                                          .tr(namedArgs: {
                                          'count': '${_serverIds.length}'
                                        }),
                                  child: _RegisteredMedicinesSection(
                                    serverItems: serverItems,
                                    expandedId: _expandedRegisteredId,
                                    modifiedMap: _modifiedRegistered,
                                    onChipTap: _handleRegisteredChipTap,
                                    onChipLongPress: (id, name) =>
                                        _handleRegisteredLongPress(
                                            context, id, name),
                                    onDoseChange: (id, dose) {
                                      setState(
                                          () => _modifiedRegistered[id] = dose);
                                    },
                                    onRemove: (id, name) =>
                                        _showDeleteConfirmation(
                                            context, id, name),
                                    registeredDoseFor: _registeredDoseFor,
                                    controllerFor: _registeredControllerFor,
                                  ),
                                ),
                              ] else
                                EmptyHint(
                                  label:
                                      'post_registration.health.medicines.empty_registered'
                                          .tr(),
                                ),

                              const SizedBox(height: 24),

                              // "Agregar nuevos"
                              Text(
                                'post_registration.health.medicines.add_new_section'
                                    .tr(),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: MedicoTokens.ink600,
                                ),
                              ),

                              const SizedBox(height: 8),

                              // Search bar
                              TextField(
                                controller: _searchController,
                                onChanged: (v) =>
                                    setState(() => _searchQuery = v),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: MedicoTokens.ink900,
                                ),
                                decoration: InputDecoration(
                                  hintText:
                                      'post_registration.health.medicines.search_hint'
                                          .tr(),
                                  hintStyle: const TextStyle(
                                      color: MedicoTokens.ink400, fontSize: 15),
                                  prefixIcon: const HugeIcon(
                                    icon: HugeIcons.strokeRoundedSearch01,
                                    size: 22,
                                    color: MedicoTokens.ink400,
                                  ),
                                  suffixIcon: _searchQuery.isNotEmpty
                                      ? IconButton(
                                          icon: const HugeIcon(
                                            icon:
                                                HugeIcons.strokeRoundedCancel01,
                                            size: 20,
                                            color: MedicoTokens.ink400,
                                          ),
                                          onPressed: () => setState(() {
                                            _searchController.clear();
                                            _searchQuery = '';
                                          }),
                                        )
                                      : null,
                                  filled: true,
                                  fillColor: MedicoTokens.ink100,
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
                                    'post_registration.health.medicines.no_medicines_toggle_label'
                                        .tr(),
                                helper:
                                    'post_registration.health.medicines.no_medicines_toggle_helper'
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
                                  'post_registration.health.medicines.none_active_caption'
                                      .tr(),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: MedicoTokens.ink500,
                                    fontStyle: FontStyle.italic,
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
                                const HugeIcon(
                                  icon: HugeIcons.strokeRoundedSearchMinus,
                                  size: 64,
                                  color: MedicoTokens.ink300,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'common.no_results'.tr(),
                                  style: const TextStyle(
                                      color: MedicoTokens.ink500),
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

                              return _MedicineTile(
                                key: ValueKey(item.id),
                                tileKey: _tileKeys[item.id]!,
                                name: item.name,
                                isSelected: isSelected,
                                isExpanded: isExpanded,
                                controller: isSelected
                                    ? _availableControllerFor(item.id)
                                    : TextEditingController(),
                                onTap: () => _handleAvailableTap(item.id),
                                onDoseChanged: (dose) {
                                  setState(
                                      () => _pendingDoseMap[item.id] = dose);
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
// Registered medicines section
// ─────────────────────────────────────────────────────────────────────────────

class _RegisteredMedicinesSection extends StatelessWidget {
  final List<MedicineModel> serverItems;
  final int? expandedId;
  final Map<int, String?> modifiedMap;
  final void Function(int id) onChipTap;
  final void Function(int id, String name) onChipLongPress;
  final void Function(int id, String? dose) onDoseChange;
  final void Function(int id, String name) onRemove;
  final String? Function(int) registeredDoseFor;
  final TextEditingController Function(int) controllerFor;

  const _RegisteredMedicinesSection({
    required this.serverItems,
    required this.expandedId,
    required this.modifiedMap,
    required this.onChipTap,
    required this.onChipLongPress,
    required this.onDoseChange,
    required this.onRemove,
    required this.registeredDoseFor,
    required this.controllerFor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: serverItems.map((item) {
        final dose = registeredDoseFor(item.id);
        final isExpanded = expandedId == item.id;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => onChipTap(item.id),
                onLongPress: () => onChipLongPress(item.id, item.name),
                child: Semantics(
                  label:
                      '${item.name}${dose != null ? ', $dose' : ''}, ${tr('post_registration.health.medicines.edit_chip_a11y')}',
                  button: true,
                  child: MedicalChip(
                    label: item.name,
                    tone: SeverityTone.mint,
                    sub: dose,
                  ),
                ),
              ),
              if (isExpanded) ...[
                const SizedBox(height: 8),
                _DoseEditor(
                  controller: controllerFor(item.id),
                  onChanged: (d) => onDoseChange(item.id, d),
                ),
                const SizedBox(height: 4),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Medicine available tile
// ─────────────────────────────────────────────────────────────────────────────

class _MedicineTile extends StatelessWidget {
  final Key tileKey;
  final String name;
  final bool isSelected;
  final bool isExpanded;
  final TextEditingController controller;
  final VoidCallback onTap;
  final ValueChanged<String?> onDoseChanged;
  final VoidCallback onRemove;

  const _MedicineTile({
    super.key,
    required this.tileKey,
    required this.name,
    required this.isSelected,
    required this.isExpanded,
    required this.controller,
    required this.onTap,
    required this.onDoseChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: tileKey,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
      decoration: BoxDecoration(
        color: isSelected ? MedicoTokens.mint50 : MedicoTokens.paper,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: isSelected
              ? const BorderSide(color: MedicoTokens.mint500, width: 3)
              : BorderSide.none,
        ),
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
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
                          color: MedicoTokens.ink900,
                        ),
                      ),
                    ),
                    if (isSelected)
                      const HugeIcon(
                        icon: HugeIcons.strokeRoundedTick02,
                        size: 20,
                        color: MedicoTokens.mint500,
                      ),
                  ],
                ),
              ),
            ),
            if (isExpanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DoseEditor(
                      controller: controller,
                      onChanged: onDoseChanged,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: onRemove,
                      style: TextButton.styleFrom(
                        foregroundColor: MedicoTokens.ink600,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'post_registration.health.medicines.remove_selection'
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
// Dose editor
// ─────────────────────────────────────────────────────────────────────────────

class _DoseEditor extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String?> onChanged;

  const _DoseEditor({
    required this.controller,
    required this.onChanged,
  });

  @override
  State<_DoseEditor> createState() => _DoseEditorState();
}

class _DoseEditorState extends State<_DoseEditor> {
  String? _errorText;

  void _validate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      setState(() => _errorText = null);
      widget.onChanged(null);
      return;
    }
    if (trimmed.length > 255) {
      setState(() {
        _errorText = 'post_registration.medicines.dose_too_long'.tr();
      });
      widget.onChanged(null);
    } else {
      setState(() => _errorText = null);
      widget.onChanged(trimmed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      maxLength: 255,
      buildCounter: (context,
              {required currentLength,
              required isFocused,
              required maxLength}) =>
          Text(
        '$currentLength/255',
        style: TextStyle(
          fontSize: 11,
          color:
              currentLength > 240 ? MedicoTokens.coral500 : MedicoTokens.ink400,
        ),
      ),
      decoration: InputDecoration(
        labelText: 'post_registration.medicines.dose_label'.tr(),
        hintText: 'post_registration.medicines.dose_hint'.tr(),
        errorText: _errorText,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: MedicoTokens.ink200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: MedicoTokens.coral500),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: MedicoTokens.coral600),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: MedicoTokens.coral600),
        ),
      ),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          iconWidget,
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: fgColor,
                height: 1.4,
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isActive ? MedicoTokens.mint50 : MedicoTokens.paper,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? MedicoTokens.mint500 : MedicoTokens.ink150,
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
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: MedicoTokens.ink900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    helper,
                    style: const TextStyle(
                      fontSize: 12,
                      color: MedicoTokens.ink500,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: isActive,
              onChanged: (_) => onTap(),
              activeThumbColor: MedicoTokens.mint500,
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
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: 12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: MedicoTokens.paper,
        border: Border(top: BorderSide(color: MedicoTokens.ink150)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _counterText(),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: MedicoTokens.ink600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: canSave && !isSaving ? onSave : null,
            style: FilledButton.styleFrom(
              backgroundColor: MedicoTokens.coral500,
              disabledBackgroundColor: MedicoTokens.ink150,
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: MedicoTokens.paper,
                    ),
                  )
                : Text(
                    'common.save'.tr(),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.1,
                      color: MedicoTokens.paper,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
