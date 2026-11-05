import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/errors/user_error_message.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/class_tone.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/features/dashboard/presentation/widgets/class_logo_box.dart';

import '../catalog/class_catalog.dart';
import '../catalog/class_catalog_providers.dart';

/// «Clases por club»: every enabled class by club type, youngest first, with
/// its ages and the user's standing (invested and when, in progress, not
/// invested). Read-only: rows do not open anything.
///
/// On load the list scrolls to the user's current class and highlights it
/// once (a short lift with a fading halo). Reduced motion skips both effects.
class ClassCatalogView extends StatelessWidget {
  const ClassCatalogView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SacTopBar(title: 'classes.catalog.title'.tr(), frosted: true),
      body: const SacFrostedVeil(child: _CatalogBody()),
    );
  }
}

class _CatalogBody extends ConsumerWidget {
  const _CatalogBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top = SacTopBar.frostedInset(context);
    final catalog = ref.watch(classCatalogProvider);

    return catalog.when(
      loading: () => const Center(child: SacLoading()),
      error: (error, _) => Padding(
        padding: EdgeInsets.only(top: top),
        child: SacErrorState(
          title: 'classes.catalog.error'.tr(),
          message: userErrorMessage(error),
          onRetry: () => refreshClassCatalog(ref),
        ),
      ),
      data: (sections) => sections.isEmpty
          ? Padding(
              padding: EdgeInsets.only(top: top),
              child: SacEmptyState(title: 'classes.catalog.empty'.tr()),
            )
          : _CatalogList(sections: sections, topInset: top),
    );
  }
}

class _CatalogList extends ConsumerStatefulWidget {
  const _CatalogList({required this.sections, required this.topInset});

  final List<ClassCatalogSection> sections;
  final double topInset;

  @override
  ConsumerState<_CatalogList> createState() => _CatalogListState();
}

class _CatalogListState extends ConsumerState<_CatalogList>
    with SingleTickerProviderStateMixin {
  /// Long enough to read as a moment, short enough not to hold the user.
  static const Duration _highlightDuration = Duration(milliseconds: 900);

  final _currentKey = GlobalKey();
  late final AnimationController _highlight = AnimationController(
    vsync: this,
    duration: _highlightDuration,
  );
  bool _introduced = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _introduceCurrent());
  }

  /// Scrolls the current class into view, then plays the highlight once.
  Future<void> _introduceCurrent() async {
    if (_introduced || !mounted) return;
    final target = _currentKey.currentContext;
    if (target == null) return;
    _introduced = true;

    final reduce = SacMotion.reduceMotionOf(context);
    await Scrollable.ensureVisible(
      target,
      // Upper third: clear of the frosted bar and in easy view.
      alignment: 0.35,
      duration: reduce ? Duration.zero : SacMotion.routeEnter * 2,
      curve: SacMotion.easeOut,
    );
    if (!mounted || reduce) return;
    await _highlight.forward(from: 0);
  }

  @override
  void dispose() {
    _highlight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hPad = Responsive.horizontalPadding(context);

    return RefreshIndicator(
      edgeOffset: widget.topInset,
      onRefresh: () => refreshClassCatalog(ref),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(hPad, widget.topInset + 8, hPad, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final section in widget.sections) ...[
              _SectionHeader(section: section),
              const SizedBox(height: 8),
              SacCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < section.entries.length; i++) ...[
                      if (i > 0 &&
                          !section.entries[i].isCurrent &&
                          !section.entries[i - 1].isCurrent)
                        Divider(
                          height: 1,
                          thickness: 1,
                          indent: 66,
                          color: context.sac.borderLight,
                        ),
                      if (section.entries[i].isCurrent)
                        _CurrentClassRow(
                          key: _currentKey,
                          entry: section.entries[i],
                          highlight: _highlight,
                        )
                      else
                        _ClassRow(entry: section.entries[i]),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.section});

  final ClassCatalogSection section;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final ages = formatClassAges(section.minAge, section.maxAge);
    final count = 'classes.catalog.class_count'.plural(section.entries.length);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'classes.catalog.club_${section.clubTypeId}'.tr(),
            style: TextStyle(
              fontSize: SacFontSize.titleLarge,
              fontWeight: FontWeight.w700,
              color: c.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            ages == null ? count : '$ages · $count',
            style: TextStyle(
              fontSize: SacFontSize.bodyMedium,
              color: c.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// «6 años», «16 a 17 años» or «Desde 21 años». Null without a minimum age.
String? formatClassAges(int? minAge, int? maxAge) {
  if (minAge == null) return null;
  if (maxAge == null) {
    return 'classes.catalog.ages_from'.tr(namedArgs: {'min': '$minAge'});
  }
  if (maxAge <= minAge) {
    return 'classes.catalog.ages_single'.tr(namedArgs: {'age': '$minAge'});
  }
  return 'classes.catalog.ages_range'
      .tr(namedArgs: {'min': '$minAge', 'max': '$maxAge'});
}

class _ClassRow extends StatelessWidget {
  const _ClassRow({required this.entry});

  final ClassCatalogEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: _RowContent(entry: entry),
    );
  }
}

/// The user's current class: an inset tile in the class tone that lifts once
/// with a fading halo when [highlight] runs.
class _CurrentClassRow extends StatelessWidget {
  const _CurrentClassRow({
    super.key,
    required this.entry,
    required this.highlight,
  });

  final ClassCatalogEntry entry;
  final Animation<double> highlight;

  static final Animatable<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 1.035)
          .chain(CurveTween(curve: SacMotion.easeOut)),
      weight: 35,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.035, end: 1.0)
          .chain(CurveTween(curve: SacMotion.easeInOut)),
      weight: 65,
    ),
  ]);

  @override
  Widget build(BuildContext context) {
    final classColor = AppColors.classColor(entry.name);
    final tone = ClassTone.of(context, classColor);
    final radius = BorderRadius.circular(AppTheme.radiusSM);

    final tile = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: tone.container,
        borderRadius: radius,
        border: Border.all(color: classColor, width: 1.5),
      ),
      child: _RowContent(
        entry: entry,
        label: 'classes.catalog.current_label'.tr(),
        labelColor: tone.onContainer,
        badgeBackground: context.sac.surface,
      ),
    );

    return Padding(
      padding: const EdgeInsets.all(4),
      child: AnimatedBuilder(
        animation: highlight,
        child: tile,
        builder: (context, child) {
          final t = highlight.value;
          // Halo grows and fades over the whole run.
          final halo = Curves.easeOut.transform(t);
          return Transform.scale(
            scale: _scale.transform(t),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                boxShadow: t == 0 || t == 1
                    ? null
                    : [
                        BoxShadow(
                          color: classColor.withValues(
                            alpha: 0.5 * (1 - halo),
                          ),
                          spreadRadius: 12 * halo,
                        ),
                      ],
              ),
              child: child,
            ),
          );
        },
      ),
    );
  }
}

class _RowContent extends StatelessWidget {
  const _RowContent({
    required this.entry,
    this.label,
    this.labelColor,
    this.badgeBackground,
  });

  final ClassCatalogEntry entry;

  /// Small caption above the name («Tu clase actual»).
  final String? label;
  final Color? labelColor;

  /// Badge fill override, so a tinted badge stays visible on a tinted tile.
  final Color? badgeBackground;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final ages = formatClassAges(entry.minAge, entry.maxAge);

    return Semantics(
      container: true,
      label: [
        if (label != null) label!,
        entry.name,
        if (ages != null) ages,
        _statusLabel(entry),
      ].join('. '),
      excludeSemantics: true,
      child: Row(
        children: [
          ClassLogoBox(
            className: entry.name,
            imageUrl: entry.imageUrl,
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (label != null)
                  Text(
                    label!,
                    style: TextStyle(
                      fontSize: SacFontSize.labelSmall,
                      fontWeight: FontWeight.w700,
                      color: labelColor,
                    ),
                  ),
                Text(
                  entry.name,
                  style: TextStyle(
                    fontSize: SacFontSize.titleSmall,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (ages != null)
                  Text(
                    ages,
                    style: TextStyle(
                      fontSize: SacFontSize.bodySmall,
                      color: c.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _StatusBadge(entry: entry, background: badgeBackground),
        ],
      ),
    );
  }
}

String _statusLabel(ClassCatalogEntry entry) {
  final year = entry.year;
  String withYear(String key) => year == null
      ? 'classes.catalog.status.$key'.tr()
      : 'classes.catalog.status.${key}_year'.tr(namedArgs: {'year': year});

  return switch (entry.status) {
    ClassCatalogStatus.invested => withYear('invested'),
    ClassCatalogStatus.inProgress => withYear('in_progress'),
    ClassCatalogStatus.expired => withYear('expired'),
    ClassCatalogStatus.notInvested =>
      'classes.catalog.status.not_invested'.tr(),
  };
}

/// Invested, expired and not invested use the app-wide status colors; in
/// progress speaks the class tone, like the class card on the home.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.entry, this.background});

  final ClassCatalogEntry entry;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final label = _statusLabel(entry);

    switch (entry.status) {
      case ClassCatalogStatus.invested:
        return SacBadge.success(label: label);
      case ClassCatalogStatus.expired:
        return SacBadge.error(label: label);
      case ClassCatalogStatus.notInvested:
        return SacBadge(label: label, variant: SacBadgeVariant.neutral);
      case ClassCatalogStatus.inProgress:
        final tone = ClassTone.of(context, AppColors.classColor(entry.name));
        return SacBadge(
          label: label,
          backgroundColor: background ?? tone.container,
          foregroundColor: tone.onContainer,
        );
    }
  }
}
