import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import '../../../../core/utils/app_logger.dart';
import '../../data/models/allergy_model.dart';
import '../providers/personal_info_providers.dart';
import '../../../profile/presentation/widgets/medico/medico_tokens.dart';
import '../../../profile/presentation/widgets/medico/medico_section_card.dart';
import '../../../profile/presentation/widgets/medico/medical_chip.dart';
import '../../../profile/presentation/widgets/medico/empty_hint.dart';

/// Redesigned view for managing user allergies.
/// - AppBar: back only, no refresh, no Save
/// - Pull-to-refresh on scroll
/// - MedicoSectionCard "Ya registradas (n)" for server items
/// - Available list EXCLUDES registered items
/// - None toggle ABOVE search
/// - Sticky footer with counter + Save CTA
class AllergiesSelectionView extends ConsumerStatefulWidget {
  const AllergiesSelectionView({super.key});

  @override
  ConsumerState<AllergiesSelectionView> createState() =>
      _AllergiesSelectionViewState();
}

class _AllergiesSelectionViewState
    extends ConsumerState<AllergiesSelectionView> {
  // ── Server state (seeded once) ──────────────────────────────────────────
  Set<int> _serverIds = {};
  bool _serverSeeded = false;

  /// Map id → severity for server-registered allergies (editable)
  final Map<int, AllergySeverity> _serverSeverityMap = {};

  /// Modified registered items (delta from server state)
  final Map<int, AllergySeverity> _modifiedRegistered = {};

  // ── Pending new selections ──────────────────────────────────────────────
  final Set<int> _selectedIds = {};
  final Map<int, AllergySeverity> _pendingSeverityMap = {};

  // ── UI state ────────────────────────────────────────────────────────────
  int? _expandedAvailableId;
  int? _expandedRegisteredId;
  bool _noneExplicit = false;
  bool _isSaving = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // ── GlobalKey for scroll-to ─────────────────────────────────────────────
  final Map<int, GlobalKey> _tileKeys = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(userAllergiesProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Seeding ─────────────────────────────────────────────────────────────

  void _seedFromServer(List<AllergyModel> items) {
    if (_serverSeeded) return;
    _serverSeeded = true;
    _serverIds = items.map((a) => a.id).toSet();
    for (final a in items) {
      _serverSeverityMap[a.id] = a.severity;
    }
  }

  // ── Tone helpers ────────────────────────────────────────────────────────

  SeverityTone _toneForSeverity(AllergySeverity s) {
    switch (s) {
      case AllergySeverity.alta:
        return SeverityTone.rose;
      case AllergySeverity.media:
        return SeverityTone.amber;
      case AllergySeverity.leve:
        return SeverityTone.mint;
    }
  }

  AllergySeverity _severityFor(int id) =>
      _pendingSeverityMap[id] ?? AllergySeverity.leve;

  AllergySeverity _registeredSeverityFor(int id) =>
      _modifiedRegistered[id] ?? _serverSeverityMap[id] ?? AllergySeverity.leve;

  // ── Pending state helpers ───────────────────────────────────────────────

  bool get _hasPendingChanges {
    if (_selectedIds.isNotEmpty) return true;
    if (_modifiedRegistered.isNotEmpty) return true;
    if (_noneExplicit && _serverIds.isNotEmpty) return true;
    if (_noneExplicit && _selectedIds.isEmpty && _serverIds.isEmpty) {
      // noneExplicit but nothing to save — not a real change
      return false;
    }
    return false;
  }

  int get _pendingCount => _selectedIds.length + _modifiedRegistered.length;

  // ── None toggle ─────────────────────────────────────────────────────────

  Future<void> _handleNoneToggle(BuildContext context) async {
    if (_noneExplicit) {
      // Turn OFF — just re-enable
      setState(() => _noneExplicit = false);
      return;
    }

    // Turn ON
    if (_selectedIds.isNotEmpty) {
      final confirmed = await SacDialog.show(
        context,
        title: 'post_registration.health.allergies.no_allergies_confirm_title'
            .tr(),
        content:
            'post_registration.health.allergies.no_allergies_confirm_content'
                .tr(),
        confirmLabel: 'common.confirm'.tr(),
      );
      if (confirmed != true) return;
      setState(() {
        _selectedIds.clear();
        _pendingSeverityMap.clear();
        _expandedAvailableId = null;
        _noneExplicit = true;
      });
      return;
    }

    if (_serverIds.isNotEmpty) {
      final count = _serverIds.length;
      final confirmed = await SacDialog.show(
        context,
        title: 'post_registration.health.allergies.no_allergies_confirm_title'
            .tr(),
        content:
            'post_registration.health.allergies.no_allergies_destructive_content'
                .tr(namedArgs: {'count': '$count'}),
        confirmLabel: 'common.confirm'.tr(),
        confirmIsDestructive: true,
      );
      if (confirmed != true) return;
    }

    setState(() {
      _selectedIds.clear();
      _pendingSeverityMap.clear();
      _expandedAvailableId = null;
      _noneExplicit = true;
    });
  }

  // ── Available list interactions ─────────────────────────────────────────

  void _handleAvailableTap(int id) {
    if (_noneExplicit) {
      // Only auto-toggle OFF if no server items
      if (_serverIds.isEmpty) {
        setState(() => _noneExplicit = false);
      }
      return;
    }

    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        _pendingSeverityMap.remove(id);
        if (_expandedAvailableId == id) _expandedAvailableId = null;
      } else {
        _selectedIds.add(id);
        _expandedAvailableId = id;
        // Ensure a default severity is set
        _pendingSeverityMap[id] ??= AllergySeverity.leve;
      }
    });

    // Scroll to tile after frame
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
      _pendingSeverityMap.remove(id);
      if (_expandedAvailableId == id) _expandedAvailableId = null;
    });
  }

  // ── Registered chip interactions ─────────────────────────────────────────

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
                    'post_registration.health.allergies.edit_chip_a11y'.tr(),
                    style: const TextStyle(color: MedicoTokens.ink900),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    setState(() {
                      _expandedRegisteredId = id;
                    });
                  },
                ),
                ListTile(
                  leading: const HugeIcon(
                    icon: HugeIcons.strokeRoundedDelete02,
                    size: 22,
                    color: MedicoTokens.coral600,
                  ),
                  title: Text(
                    'post_registration.health.allergies.remove_selection'.tr(),
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
    int allergyId,
    String allergyName,
  ) async {
    final confirmed = await SacDialog.show(
      context,
      title: 'post_registration.health.allergies.delete_dialog_title'.tr(),
      content: 'post_registration.health.allergies.delete_dialog_content'
          .tr(namedArgs: {'name': allergyName}),
      confirmLabel: 'common.delete'.tr(),
      confirmIsDestructive: true,
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(userAllergiesProvider.notifier).deleteAllergy(allergyId);
        setState(() {
          _serverIds.remove(allergyId);
          _serverSeverityMap.remove(allergyId);
          _modifiedRegistered.remove(allergyId);
          if (_expandedRegisteredId == allergyId) _expandedRegisteredId = null;
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'post_registration.health.allergies.delete_success'.tr()),
              backgroundColor: MedicoTokens.mint500,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } catch (e) {
        AppLogger.e('Delete allergy error', tag: 'AllergiesView', error: e);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'post_registration.health.allergies.delete_error'
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

  // ── Pull-to-refresh ─────────────────────────────────────────────────────

  Future<void> _onRefresh() async {
    setState(() {
      _serverSeeded = false;
    });
    ref.read(allergiesCatalogProvider);
    await ref.read(userAllergiesProvider.notifier).refresh();
  }

  // ── Save ────────────────────────────────────────────────────────────────

  Future<void> _save(BuildContext context) async {
    if (_isSaving || !_hasPendingChanges) return;

    setState(() {
      _isSaving = true;
    });

    try {
      // Build the final list:
      // - Registered items WITH modifications applied
      // - NEW selected items
      // - If noneExplicit, save empty list (deleteAll + saveAll([]))

      final List<AllergyEntry> entries = [];

      if (!_noneExplicit) {
        // Keep existing registered with possible modifications
        for (final id in _serverIds) {
          entries.add(AllergyEntry(
            id: id,
            severity: _registeredSeverityFor(id),
          ));
        }
        // Add new selections
        for (final id in _selectedIds) {
          entries.add(AllergyEntry(
            id: id,
            severity: _severityFor(id),
          ));
        }
      }
      // If noneExplicit → entries is empty → saveAll([]) clears everything

      await ref.read(userAllergiesProvider.notifier).saveAll(entries);

      // Re-seed from updated server state
      final updated = ref.read(userAllergiesProvider).valueOrNull ?? [];
      setState(() {
        _serverSeeded = false;
        _selectedIds.clear();
        _pendingSeverityMap.clear();
        _modifiedRegistered.clear();
        _expandedAvailableId = null;
        _expandedRegisteredId = null;
        _isSaving = false;
        _noneExplicit = false;
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
      AppLogger.e('Save allergies error', tag: 'AllergiesView', error: e);
      setState(() {
        _isSaving = false;
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'common.save_error_retry'.tr(),
            ),
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

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Seed once when user allergies arrive
    ref.listen<AsyncValue<List<AllergyModel>>>(
      userAllergiesProvider,
      (prev, next) {
        if (next.value != null && !_serverSeeded) {
          _seedFromServer(next.value!);
          // Also init selectedIds provider for backwards compat
          ref.read(selectedAllergiesProvider.notifier).state =
              next.value!.map((a) => a.id).toList();
        }
      },
    );

    final catalogAsync = ref.watch(allergiesCatalogProvider);
    final userAsync = ref.watch(userAllergiesProvider);

    return Scaffold(
      backgroundColor: MedicoTokens.canvas,
      appBar: AppBar(
        backgroundColor: MedicoTokens.paper,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'post_registration.health.allergies.title'.tr(),
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
                  'post_registration.health.allergies.load_error'
                      .tr(namedArgs: {'error': error.toString()}),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => ref.refresh(allergiesCatalogProvider),
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

          // Available = catalog minus server-registered
          final available = catalog
              .where((a) => !_serverIds.contains(a.id))
              .where((a) =>
                  _searchQuery.isEmpty ||
                  a.name.toLowerCase().contains(_searchQuery.toLowerCase()))
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
                              // ── Info banner ──────────────────────────
                              _InfoBanner(
                                text:
                                    'post_registration.health.allergies.info_text'
                                        .tr(),
                                bgColor: MedicoTokens.rose50,
                                fgColor: MedicoTokens.roseInk,
                                iconWidget: const HugeIcon(
                                  icon: HugeIcons.strokeRoundedFirstAidKit,
                                  size: 20,
                                  color: MedicoTokens.rose500,
                                ),
                              ),

                              const SizedBox(height: 20),

                              // ── Ya registradas ───────────────────────
                              if (userAsync.isLoading)
                                const Center(child: SacLoading())
                              else if (_serverIds.isNotEmpty) ...[
                                MedicoSectionCard(
                                  iconWidget: const HugeIcon(
                                    icon: HugeIcons.strokeRoundedFirstAidKit,
                                    size: 20,
                                    color: MedicoTokens.rose500,
                                  ),
                                  iconBg: MedicoTokens.rose50,
                                  title: _registeredTitle(
                                      context, _serverIds.length),
                                  child: _RegisteredChipsSection(
                                    serverItems: serverItems,
                                    expandedId: _expandedRegisteredId,
                                    modifiedMap: _modifiedRegistered,
                                    serverSeverityMap: _serverSeverityMap,
                                    onChipTap: _handleRegisteredChipTap,
                                    onChipLongPress: (id, name) =>
                                        _handleRegisteredLongPress(
                                            context, id, name),
                                    onSeverityChange: (id, sev) {
                                      setState(
                                          () => _modifiedRegistered[id] = sev);
                                    },
                                    onRemove: (id, name) =>
                                        _showDeleteConfirmation(
                                            context, id, name),
                                    toneForSeverity: _toneForSeverity,
                                    registeredSeverityFor:
                                        _registeredSeverityFor,
                                  ),
                                ),
                              ] else ...[
                                EmptyHint(
                                  label: 'post_registration.health.allergies'
                                          '.empty_registered'
                                      .tr(),
                                ),
                              ],

                              const SizedBox(height: 24),

                              // ── "Agregar nuevas" label ────────────────
                              Text(
                                'post_registration.health.allergies.add_new_section'
                                    .tr(),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: MedicoTokens.ink600,
                                ),
                              ),

                              const SizedBox(height: 8),

                              // ── Search bar ───────────────────────────
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
                                      'post_registration.health.allergies.search_hint'
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

                              // ── None toggle ──────────────────────────
                              _NoneToggleCard(
                                isActive: _noneExplicit,
                                label:
                                    'post_registration.health.allergies.no_allergies_toggle_label'
                                        .tr(),
                                helper:
                                    'post_registration.health.allergies.no_allergies_toggle_helper'
                                        .tr(),
                                onTap: () => _handleNoneToggle(context),
                              ),

                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ),

                      // ── Available list ────────────────────────────────
                      if (_noneExplicit)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            child: Opacity(
                              opacity: 0.4,
                              child: IgnorePointer(
                                child: Text(
                                  'post_registration.health.allergies.none_active_caption'
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
                              final severity = _severityFor(item.id);
                              final tone = _toneForSeverity(severity);
                              final toneData = MedicoTokens.toneFor(tone);

                              _tileKeys[item.id] ??= GlobalKey();

                              return _AvailableTile(
                                key: ValueKey(item.id),
                                tileKey: _tileKeys[item.id]!,
                                name: item.name,
                                isSelected: isSelected,
                                isExpanded: isExpanded,
                                tone: tone,
                                toneData: toneData,
                                selectedSeverity: severity,
                                onTap: () => _handleAvailableTap(item.id),
                                onSeverityChanged: (sev) {
                                  setState(() {
                                    _pendingSeverityMap[item.id] = sev;
                                  });
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

              // ── Sticky footer ────────────────────────────────────────
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

  String _registeredTitle(BuildContext context, int count) {
    if (count == 1) {
      return 'post_registration.health.allergies.registered_count_one'.tr();
    }
    return 'post_registration.health.allergies.registered_count'
        .tr(namedArgs: {'count': '$count'});
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Registered chips section (inside MedicoSectionCard)
// ─────────────────────────────────────────────────────────────────────────────

class _RegisteredChipsSection extends StatelessWidget {
  final List<AllergyModel> serverItems;
  final int? expandedId;
  final Map<int, AllergySeverity> modifiedMap;
  final Map<int, AllergySeverity> serverSeverityMap;
  final void Function(int id) onChipTap;
  final void Function(int id, String name) onChipLongPress;
  final void Function(int id, AllergySeverity sev) onSeverityChange;
  final void Function(int id, String name) onRemove;
  final SeverityTone Function(AllergySeverity) toneForSeverity;
  final AllergySeverity Function(int) registeredSeverityFor;

  const _RegisteredChipsSection({
    required this.serverItems,
    required this.expandedId,
    required this.modifiedMap,
    required this.serverSeverityMap,
    required this.onChipTap,
    required this.onChipLongPress,
    required this.onSeverityChange,
    required this.onRemove,
    required this.toneForSeverity,
    required this.registeredSeverityFor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: serverItems.map((item) {
        final sev = registeredSeverityFor(item.id);
        final tone = toneForSeverity(sev);
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
                      '${item.name}, ${sev.i18nKey.tr()}, ${tr('post_registration.health.allergies.edit_chip_a11y')}',
                  button: true,
                  child: MedicalChip(
                    label: item.name,
                    tone: tone,
                    sub: sev.i18nKey.tr(),
                  ),
                ),
              ),
              if (isExpanded) ...[
                const SizedBox(height: 8),
                _CompactSeverityEditor(
                  selected: sev,
                  onChanged: (s) => onSeverityChange(item.id, s),
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
// Available tile (idle + expanded inline editor)
// ─────────────────────────────────────────────────────────────────────────────

class _AvailableTile extends StatelessWidget {
  final Key tileKey;
  final String name;
  final bool isSelected;
  final bool isExpanded;
  final SeverityTone tone;
  final ChipTone toneData;
  final AllergySeverity selectedSeverity;
  final VoidCallback onTap;
  final ValueChanged<AllergySeverity> onSeverityChanged;
  final VoidCallback onRemove;

  const _AvailableTile({
    super.key,
    required this.tileKey,
    required this.name,
    required this.isSelected,
    required this.isExpanded,
    required this.tone,
    required this.toneData,
    required this.selectedSeverity,
    required this.onTap,
    required this.onSeverityChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: tileKey,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
      decoration: BoxDecoration(
        color: isSelected ? toneData.bg : MedicoTokens.paper,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: isSelected
              ? BorderSide(color: toneData.dot, width: 3)
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
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedTick02,
                        size: 20,
                        color: toneData.dot,
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
                    _CompactSeverityEditor(
                      selected: selectedSeverity,
                      onChanged: onSeverityChanged,
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
                        'post_registration.health.allergies.remove_selection'
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
// Compact severity editor (SegmentedButton)
// ─────────────────────────────────────────────────────────────────────────────

class _CompactSeverityEditor extends StatelessWidget {
  final AllergySeverity selected;
  final ValueChanged<AllergySeverity> onChanged;

  const _CompactSeverityEditor({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<AllergySeverity>(
      segments: [
        ButtonSegment(
          value: AllergySeverity.leve,
          label: Text(
            'profile.medical_info.severity.leve'.tr(),
            style: const TextStyle(fontSize: 12),
          ),
        ),
        ButtonSegment(
          value: AllergySeverity.media,
          label: Text(
            'profile.medical_info.severity.media'.tr(),
            style: const TextStyle(fontSize: 12),
          ),
        ),
        ButtonSegment(
          value: AllergySeverity.alta,
          label: Text(
            'profile.medical_info.severity.alta'.tr(),
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
      selected: {selected},
      onSelectionChanged: (s) {
        if (s.isNotEmpty) onChanged(s.first);
      },
      style: ButtonStyle(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return MedicoTokens.coral500;
          }
          return MedicoTokens.paper;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return MedicoTokens.paper;
          }
          return MedicoTokens.ink600;
        }),
      ),
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
      'pending': '$pendingCount'
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
                    isSaving ? 'common.saving'.tr() : 'common.save'.tr(),
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
