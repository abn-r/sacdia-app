import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/badge_grid/sac_badge_tint.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_state_panel.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_status_style.dart';
import 'package:sacdia_app/features/master_honors/domain/entities/master_honor_roadmap.dart';
import 'package:sacdia_app/features/master_honors/presentation/widgets/master_honor_detail_presentation.dart';
import 'package:sacdia_app/features/master_honors/presentation/widgets/master_honor_logo.dart';
import 'package:sacdia_app/features/master_honors/presentation/widgets/master_honor_requirements_section.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';

Future<void> showMasterHonorDetailSheet(
  BuildContext context,
  MasterHonorRoadmap item,
) {
  return showSacSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => MasterHonorDetailSheet(item: item),
  );
}

/// Detail of a mastery: the patch and its full name, one status panel that
/// says where the user stands and what is missing, and the requirements with
/// the honors that already count.
class MasterHonorDetailSheet extends StatefulWidget {
  const MasterHonorDetailSheet({super.key, required this.item});

  final MasterHonorRoadmap item;

  @override
  State<MasterHonorDetailSheet> createState() => _MasterHonorDetailSheetState();
}

class _MasterHonorDetailSheetState extends State<MasterHonorDetailSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(vsync: this, duration: SacMotion.modal);
    _fade = CurvedAnimation(parent: _enter, curve: SacMotion.easeOut);
    _scale = Tween<double>(begin: SacMotion.enterScale, end: 1).animate(
      CurvedAnimation(parent: _enter, curve: SacMotion.easeOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (SacMotion.reduceMotionOf(context)) {
      _enter.value = 1;
    } else if (!_enter.isAnimating && _enter.value == 0) {
      _enter.forward();
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final visual = masterHonorGridVisual(item);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final c = context.sac;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusXL)),
            boxShadow: [
              BoxShadow(
                color: c.shadow,
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusXL)),
            child: Column(
              children: [
                const SacSheetGrabber(),
                Expanded(
                  child: FadeTransition(
                    opacity: _fade,
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: EdgeInsets.fromLTRB(0, 16, 0, 28 + bottomInset),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: ScaleTransition(
                              scale: _scale,
                              child: SacBadgeTint.tone(
                                tone: masterHonorTone(visual),
                                child: MasterHonorLogo(
                                  imageUrl: item.masterImage,
                                  name: masterHonorShortName(item.name),
                                  size: _kHeroHeight,
                                  width: _kHeroWidth,
                                  color: SacAccent.of(context).color,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              item.name,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: SacFontSize.headlineLarge,
                                fontWeight: FontWeight.w800,
                                color: c.text,
                                height: 1.15,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                            child: _StatusPanel(item: item, visual: visual),
                          ),
                          MasterHonorRequirementsSection(
                            item: item,
                            isLapsed: visual == MasterHonorGridVisual.inactive,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Patch of the hero: 120 wide, as in the design.
const double _kHeroWidth = 120;
const double _kHeroHeight = 96;

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.item, required this.visual});

  final MasterHonorRoadmap item;
  final MasterHonorGridVisual visual;

  @override
  Widget build(BuildContext context) {
    final copy = MasterHonorStatusCopy.of(item);
    final c = context.sac;

    final style = switch (visual) {
      MasterHonorGridVisual.awarded => SacStatusStyle.of(
          context,
          SacStatusKind.validated,
          label: copy.title,
        ),
      MasterHonorGridVisual.inProgress => SacStatusStyle.of(
          context,
          SacStatusKind.review,
          label: copy.title,
          icon: HugeIcons.strokeRoundedClock01,
        ),
      MasterHonorGridVisual.inactive => SacStatusStyle(
          kind: SacStatusKind.pending,
          container: c.warningContainer,
          onContainer: c.onWarningContainer,
          solid: c.warning,
          icon: HugeIcons.strokeRoundedAlert02,
          label: copy.title,
        ),
      MasterHonorGridVisual.locked => SacStatusStyle.of(
          context,
          SacStatusKind.pending,
          label: copy.title,
          icon: HugeIcons.strokeRoundedInformationCircle,
        ),
    };

    return SacStatePanel(
      style: style,
      title: copy.title,
      message: copy.message,
    );
  }
}
