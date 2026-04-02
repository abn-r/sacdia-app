import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sacdia_app/core/animations/page_transitions.dart';
import 'package:sacdia_app/core/animations/staggered_list_animation.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';

import 'package:sacdia_app/providers/catalogs_provider.dart';
import 'package:sacdia_app/features/auth/domain/utils/authorization_utils.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import '../../../members/presentation/providers/members_providers.dart';

import '../../domain/entities/activity.dart';
import '../providers/activities_providers.dart';
import '../widgets/activities_loading_skeleton.dart';
import '../widgets/activity_card.dart';
import 'activity_detail_view.dart';
import 'create_activity_view.dart';

/// Vista de lista de actividades - Estilo "Scout Vibrante"
///
/// Strip horizontal de fechas, chips de filtro por tipo,
/// ActivityCards rediseñadas con chip de tipo y metadata.
///
/// Cuando no se provee [clubId] explícitamente, la vista lo resuelve desde
/// [clubContextProvider] usando el contexto activo del usuario autenticado.
class ActivitiesListView extends ConsumerStatefulWidget {
  /// ID del club. Si es null, se resuelve desde [clubContextProvider].
  final int? clubId;

  /// ID del tipo de club usado para filtrar actividades en el backend
  /// (p.ej. 1 = Aventureros, 2 = Conquistadores, 3 = Guias Mayores).
  final int? clubTypeId;

  /// ID de la sección del club (club_sections).
  /// Si es null y clubId también es null, se resuelve desde [clubContextProvider].
  final int? clubSectionId;

  const ActivitiesListView({
    super.key,
    this.clubId,
    this.clubTypeId,
    this.clubSectionId,
  });

  @override
  ConsumerState<ActivitiesListView> createState() => _ActivitiesListViewState();
}

class _ActivitiesListViewState extends ConsumerState<ActivitiesListView> {
  int? _selectedFilter;
  DateTime? _selectedDate;
  bool _isChronologicalView = false;
  bool _shouldScrollToToday = false;
  late final List<DateTime> _days;
  late final int _todayIndex;
  late final ScrollController _dateScrollController;
  late final ScrollController _chronoScrollController;
  late DateTime _visibleMonth;
  bool _showTodayButton = false;

  static const double _dateItemWidth = 52.0;
  static const double _dateItemHorizontalMargin = 4.0;

  @override
  void initState() {
    super.initState();
    _days = _buildDays();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _visibleMonth = DateTime(now.year, now.month);
    _todayIndex = _days.indexWhere((d) => _isSameDay(d, now));
    _dateScrollController = ScrollController();
    _chronoScrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToToday());
  }

  @override
  void dispose() {
    _dateScrollController.dispose();
    _chronoScrollController.dispose();
    super.dispose();
  }

  bool _canCreateActivities() {
    final authState = ref.read(authNotifierProvider);
    final user = authState.valueOrNull;
    if (user == null) return false;
    return canByPermissionOrLegacyRole(
      user,
      requiredPermissions: const {'activities:create'},
      legacyRoles: const {
        'director',
        'deputy_director',
        'secretary',
        'counselor',
      },
    );
  }

  List<DateTime> _buildDays() {
    final now = DateTime.now();
    final start = DateTime(now.year, 1, 1);
    final end = DateTime(now.year, 12, 31);
    final count = end.difference(start).inDays + 1;
    return List.generate(count, (i) => start.add(Duration(days: i)));
  }

  double _offsetForIndex(int index) {
    const itemTotalWidth = _dateItemWidth + _dateItemHorizontalMargin * 2;
    final viewportWidth =
        _dateScrollController.hasClients ? _dateScrollController.position.viewportDimension : 334.0;
    final offset = index * itemTotalWidth - (viewportWidth / 2) + (itemTotalWidth / 2);
    return offset.clamp(0.0, double.infinity);
  }

  void _scrollToToday({bool animate = false}) {
    if (!_dateScrollController.hasClients) return;
    final offset = _offsetForIndex(_todayIndex);
    if (animate) {
      _dateScrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _dateScrollController.jumpTo(offset);
    }
  }

  void _scrollToIndex(int index, {bool animate = true}) {
    if (!_dateScrollController.hasClients) return;
    final offset = _offsetForIndex(index);
    if (animate) {
      _dateScrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _dateScrollController.jumpTo(offset);
    }
  }

  void _onDateStripScroll() {
    if (!_dateScrollController.hasClients) return;
    const itemTotalWidth = _dateItemWidth + _dateItemHorizontalMargin * 2;
    final scrollOffset = _dateScrollController.offset;
    final viewportWidth = _dateScrollController.position.viewportDimension;
    final centerOffset = scrollOffset + viewportWidth / 2;
    final centerIndex = (centerOffset / itemTotalWidth).round().clamp(0, _days.length - 1);
    final centeredDay = _days[centerIndex];
    final newMonth = DateTime(centeredDay.year, centeredDay.month);

    final todayOffset = _offsetForIndex(_todayIndex);
    final isAwayFromToday = (scrollOffset - todayOffset).abs() > itemTotalWidth * 1.5;

    if (newMonth != _visibleMonth || isAwayFromToday != _showTodayButton) {
      setState(() {
        _visibleMonth = newMonth;
        _showTodayButton = isAwayFromToday;
      });
    }
  }

  Future<void> _openDatePicker(BuildContext context) async {
    final now = DateTime.now();
    final yearStart = DateTime(now.year, 1, 1);
    final yearEnd = DateTime(now.year, 12, 31);
    final initial = _selectedDate ?? DateTime(now.year, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(yearStart)
          ? yearStart
          : initial.isAfter(yearEnd)
              ? yearEnd
              : initial,
      firstDate: yearStart,
      lastDate: yearEnd,
      locale: const Locale('es'),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
                primary: AppColors.primary,
              ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    final pickedDay = DateTime(picked.year, picked.month, picked.day);
    final idx = _days.indexWhere((d) => _isSameDay(d, pickedDay));
    if (idx < 0) return;
    setState(() => _selectedDate = pickedDay);
    _scrollToIndex(idx);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _capitalizeFirst(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  List<dynamic> _buildChronoItems(List<Activity> activities) {
    final withDates = activities.where((a) => a.activityDate != null).toList()
      ..sort((a, b) => a.activityDate!.compareTo(b.activityDate!));
    final noDates = activities.where((a) => a.activityDate == null).toList();

    final items = <dynamic>[];
    DateTime? lastDay;

    for (final a in withDates) {
      final local = a.activityDate!.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      if (lastDay == null || !_isSameDay(day, lastDay)) {
        items.add(day);
        lastDay = day;
      }
      items.add(a);
    }

    if (noDates.isNotEmpty) {
      items.add(null);
      items.addAll(noDates);
    }
    return items;
  }

  double _estimateTodayOffset(List<dynamic> items) {
    const headerH = 52.0;
    const cardH = 156.0;
    const topPad = 8.0;
    double offset = topPad;
    final today = DateTime.now();
    for (final item in items) {
      if (item is DateTime) {
        if (_isSameDay(item, today)) break;
        if (item.isAfter(today)) break;
        offset += headerH;
      } else if (item != null) {
        offset += cardH;
      }
    }
    return offset;
  }

  String _dayLabel(DateTime date) {
    final today = DateTime.now();
    if (_isSameDay(date, today)) return 'Hoy';
    if (_isSameDay(date, today.subtract(const Duration(days: 1))))
      return 'Ayer';
    if (_isSameDay(date, today.add(const Duration(days: 1)))) return 'Mañana';
    return _capitalizeFirst(DateFormat('EEEE, d MMM', 'es').format(date));
  }

  @override
  Widget build(BuildContext context) {
    final clubCtxAsync = ref.watch(clubContextProvider);
    final resolvedClubId = widget.clubId ?? clubCtxAsync.valueOrNull?.clubId;
    final resolvedSectionId =
        widget.clubSectionId ?? clubCtxAsync.valueOrNull?.sectionId;

    final activitiesAsync = resolvedClubId != null
        ? ref.watch(clubActivitiesProvider(ClubActivitiesParams(
            clubId: resolvedClubId,
            clubTypeId: widget.clubTypeId,
          )))
        : const AsyncValue<List<Activity>>.loading();
    final activityTypesAsync = ref.watch(activityTypesProvider);
    final c = context.sac;
    final today = DateTime.now();

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedCalendar01,
                      size: 22,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Actividades',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          _capitalizeFirst(
                            DateFormat('MMMM yyyy', 'es').format(_visibleMonth),
                          ),
                          style: TextStyle(
                            fontSize: 13,
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_canCreateActivities())
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          SacSlideUpRoute(
                            builder: (context) => CreateActivityView(
                              clubId: resolvedClubId ?? 0,
                              clubSectionId: resolvedSectionId ?? 0,
                            ),
                          ),
                        ).then((created) {
                          // Si la actividad fue creada, refrescar la lista
                          if (created == true && mounted) {
                            ref.invalidate(clubActivitiesProvider);
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: c.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            HugeIcon(
                              icon: HugeIcons.strokeRoundedCalendarAdd01,
                              size: 20,
                              color: c.textSecondary,
                            ),
                            const SizedBox(width: 5),
                            Text('Agregar')
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isChronologicalView = !_isChronologicalView;
                        if (_isChronologicalView) _shouldScrollToToday = true;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: _isChronologicalView
                            ? AppColors.primary
                            : c.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isChronologicalView
                              ? AppColors.primary
                              : c.border,
                        ),
                        boxShadow: _isChronologicalView
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                )
                              ]
                            : null,
                      ),
                      child: HugeIcon(
                        icon: _isChronologicalView
                            ? HugeIcons.strokeRoundedCalendar01
                            : HugeIcons.strokeRoundedListView,
                        size: 20,
                        color: _isChronologicalView
                            ? Colors.white
                            : c.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Date strip (solo en vista de tarjetas)
            ClipRect(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: _isChronologicalView
                    ? const SizedBox(height: 0)
                    : Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 76,
                                  child: NotificationListener<ScrollNotification>(
                                    onNotification: (notification) {
                                      if (notification is ScrollUpdateNotification ||
                                          notification is ScrollEndNotification) {
                                        _onDateStripScroll();
                                      }
                                      return false;
                                    },
                                    child: ListView.builder(
                                      controller: _dateScrollController,
                                      scrollDirection: Axis.horizontal,
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      itemCount: _days.length,
                                      itemBuilder: (context, index) {
                                        final day = _days[index];
                                        final isToday = _isSameDay(day, today);
                                        final isSelected = _selectedDate != null &&
                                            _isSameDay(day, _selectedDate!);

                                        return GestureDetector(
                                          onTap: () => setState(() {
                                            _selectedDate = day;
                                          }),
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 200),
                                            width: 52,
                                            margin: const EdgeInsets.symmetric(
                                                horizontal: 4, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? AppColors.primary
                                                  : isToday
                                                      ? AppColors.primaryLight
                                                      : c.surface,
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(
                                                color: isToday && !isSelected
                                                    ? AppColors.primary.withOpacity(0.35)
                                                    : Colors.transparent,
                                                width: 1.5,
                                              ),
                                              boxShadow: isSelected
                                                  ? [
                                                      BoxShadow(
                                                        color: AppColors.primary
                                                            .withOpacity(0.28),
                                                        blurRadius: 8,
                                                        offset: const Offset(0, 3),
                                                      )
                                                    ]
                                                  : null,
                                            ),
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  DateFormat('EEE', 'es')
                                                      .format(day)
                                                      .substring(0, 2)
                                                      .toUpperCase(),
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: isSelected
                                                        ? Colors.white.withOpacity(0.8)
                                                        : c.textTertiary,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  DateFormat('d').format(day),
                                                  style: TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.w700,
                                                    height: 1,
                                                    color: isSelected
                                                        ? Colors.white
                                                        : isToday
                                                            ? AppColors.primary
                                                            : c.text,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    GestureDetector(
                                      onTap: () => _openDatePicker(context),
                                      child: Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryLight,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: AppColors.primary.withOpacity(0.25),
                                          ),
                                        ),
                                        child: Center(
                                          child: HugeIcon(
                                            icon: HugeIcons.strokeRoundedCalendar02,
                                            size: 20,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (_showTodayButton) ...[
                                      const SizedBox(height: 4),
                                      GestureDetector(
                                        onTap: () {
                                          final now = DateTime.now();
                                          setState(() {
                                            _selectedDate = DateTime(now.year, now.month, now.day);
                                            _showTodayButton = false;
                                            _visibleMonth = DateTime(now.year, now.month);
                                          });
                                          _scrollToToday(animate: true);
                                        },
                                        child: Container(
                                          width: 44,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Center(
                                            child: Text(
                                              'Hoy',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                        ],
                      ),
              ),
            ),

            // Filter chips - cargados dinámicamente desde el catálogo
            SizedBox(
              height: 36,
              child: activityTypesAsync.when(
                loading: () => ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: 4,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) => _FilterChipSkeleton(c: c),
                ),
                error: (_, __) => ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _ActivityFilterChip(
                      label: 'Todas',
                      isSelected: _selectedFilter == null,
                      c: c,
                      onTap: () => setState(() => _selectedFilter = null),
                    ),
                  ],
                ),
                data: (types) {
                  final chips = <Widget>[
                    _ActivityFilterChip(
                      label: 'Todas',
                      isSelected: _selectedFilter == null,
                      c: c,
                      onTap: () => setState(() => _selectedFilter = null),
                    ),
                    ...types.map(
                      (t) => _ActivityFilterChip(
                        label: t.name,
                        isSelected: _selectedFilter == t.activityTypeId,
                        c: c,
                        onTap: () => setState(
                            () => _selectedFilter = t.activityTypeId),
                      ),
                    ),
                  ];
                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: chips.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => chips[i],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Activities list
            Expanded(
              child: activitiesAsync.when(
                data: (activities) {
                  // Activity type filter is applied locally — no new request needed.
                  // Date filter is also applied locally.
                  var filtered = _selectedFilter != null
                      ? activities.where((a) => a.activityType == _selectedFilter).toList()
                      : List.of(activities);

                  if (!_isChronologicalView && _selectedDate != null) {
                    filtered = filtered.where((a) {
                      if (a.activityDate == null) return false;
                      final start = a.activityDate!.toLocal();
                      final end = a.activityEndDate?.toLocal() ?? start;
                      final startDay = DateTime(start.year, start.month, start.day);
                      final endDay = DateTime(end.year, end.month, end.day);
                      final sel = DateTime(
                        _selectedDate!.year,
                        _selectedDate!.month,
                        _selectedDate!.day,
                      );
                      return !sel.isBefore(startDay) && !sel.isAfter(endDay);
                    }).toList();
                  }

                  late final Widget content;

                  if (filtered.isEmpty) {
                    content = Center(
                      key: ValueKey('empty-$_isChronologicalView'),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedCalendar04,
                            size: 56,
                            color: c.textTertiary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            !_isChronologicalView && _selectedDate != null
                                ? 'No hay actividades este día'
                                : _selectedFilter != null
                                    ? 'No hay actividades de este tipo'
                                    : 'No hay actividades disponibles',
                            style: TextStyle(
                              fontSize: 16,
                              color: c.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  } else if (_isChronologicalView) {
                    // ── Vista cronológica ─────────────────────────────
                    final chronoItems = _buildChronoItems(filtered);

                    if (_shouldScrollToToday) {
                      _shouldScrollToToday = false;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (_chronoScrollController.hasClients) {
                          final offset = _estimateTodayOffset(chronoItems);
                          _chronoScrollController.animateTo(
                            offset.clamp(
                                0.0,
                                _chronoScrollController
                                    .position.maxScrollExtent),
                            duration: const Duration(milliseconds: 450),
                            curve: Curves.easeOut,
                          );
                        }
                      });
                    }

                    content = RefreshIndicator(
                      key: const ValueKey('chrono'),
                      color: AppColors.primary,
                      onRefresh: () async {
                        ref.invalidate(clubActivitiesProvider);
                      },
                      child: ListView.builder(
                        controller: _chronoScrollController,
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        itemCount: chronoItems.length,
                        itemBuilder: (context, index) {
                          final item = chronoItems[index];
                          if (item is DateTime) {
                            return _DayHeaderItem(
                              label: _dayLabel(item),
                              isToday: _isSameDay(item, today),
                            );
                          }
                          if (item == null) {
                            return const _DayHeaderItem(
                              label: 'Sin fecha',
                              isToday: false,
                            );
                          }
                          final activity = item as Activity;
                          return StaggeredListItem(
                            index: index,
                            child: ActivityCard(
                              activity: activity,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  SacSharedAxisRoute(
                                    builder: (context) => ActivityDetailView(
                                      activityId: activity.id,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    );
                  } else {
                    // ── Vista de tarjetas (default) ───────────────────
                    content = RefreshIndicator(
                      key: const ValueKey('card'),
                      color: AppColors.primary,
                      onRefresh: () async {
                        ref.invalidate(clubActivitiesProvider);
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final activity = filtered[index];
                          return StaggeredListItem(
                            index: index,
                            child: ActivityCard(
                              activity: activity,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  SacSharedAxisRoute(
                                    builder: (context) => ActivityDetailView(
                                      activityId: activity.id,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    );
                  }

                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.04, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: content,
                  );
                },
                loading: () => const ActivitiesLoadingSkeleton(),
                error: (error, stack) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedAlert02,
                          size: 56,
                          color: AppColors.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error al cargar actividades',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 24),
                        SacButton.primary(
                          text: 'Reintentar',
                          icon: HugeIcons.strokeRoundedRefresh,
                          onPressed: () {
                            ref.invalidate(clubActivitiesProvider);
                          },
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

      // Botón flotante dentro del body para evitar que sea recortado por el widget padre
      // bottomNavigationBar: Padding(
      //   padding: const EdgeInsets.fromLTRB(0, 0, 16, 16),
      //   child: Row(
      //     mainAxisAlignment: MainAxisAlignment.end,
      //     children: [
      //       FloatingActionButton.extended(
      //         heroTag: 'fab_nueva_actividad',
      //         onPressed: () {
      //           Navigator.push(
      //             context,
      //             MaterialPageRoute(
      //               builder: (context) => CreateActivityView(
      //                 clubId: widget.clubId,
      //                 clubSectionId: widget.clubSectionId ?? 0,
      //               ),
      //             ),
      //           ).then((created) {
      //             // Si la actividad fue creada, refrescar la lista
      //             if (created == true && mounted) {
      //               ref.invalidate(clubActivitiesProvider);
      //             }
      //           });
      //         },
      //         backgroundColor: AppColors.primary,
      //         foregroundColor: Colors.white,
      //         elevation: 4,
      //         icon: const Icon(Icons.add_rounded, size: 22),
      //         label: const Text(
      //           'Nueva Actividad',
      //           style: TextStyle(fontWeight: FontWeight.w600),
      //         ),
      //       ),
      //     ],
      //   ),
      // ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter chip helpers
// ─────────────────────────────────────────────────────────────────────────────

class _ActivityFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final SacColors c;
  final VoidCallback onTap;

  const _ActivityFilterChip({
    required this.label,
    required this.isSelected,
    required this.c,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : c.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : c.border,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : c.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _FilterChipSkeleton extends StatelessWidget {
  final SacColors c;

  const _FilterChipSkeleton({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 36,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _DayHeaderItem extends StatelessWidget {
  final String label;
  final bool isToday;

  const _DayHeaderItem({required this.label, required this.isToday});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Row(
        children: [
          if (isToday)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            )
          else
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: c.textSecondary,
              ),
            ),
          const SizedBox(width: 10),
          Expanded(child: Divider(color: c.divider, height: 1)),
        ],
      ),
    );
  }
}
