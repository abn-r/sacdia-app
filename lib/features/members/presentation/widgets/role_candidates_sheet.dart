import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';

import '../../domain/entities/role_candidate.dart';
import '../providers/members_providers.dart';
import '../providers/role_candidates_providers.dart';
import 'role_candidate_confirm_step.dart';
import 'role_candidate_detail_step.dart';
import 'role_candidate_role_step.dart';
import 'role_candidates_list_step.dart';

/// Opens «Agregar directivo» for the active AV/CQ section. On success shows the
/// «Cargo asignado» snackbar on [context] (the sheet sits above the page's own
/// scaffold, so it cannot show it itself).
Future<void> showRoleCandidatesSheet(
  BuildContext context, {
  required ClubContext clubContext,
}) async {
  final assignedRole = await showSacSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => RoleCandidatesSheet(clubContext: clubContext),
  );
  if (assignedRole == null || !context.mounted) return;
  SacSnackBar.show(
    context,
    tr('members.role_assignment.assigned_role',
        namedArgs: {'role': assignedRole}),
    isSuccess: true,
  );
}

enum _Step { list, roles, confirm, detail }

/// The sheet: list of Guías Mayores (step 1), roles with slot state (step 2),
/// confirmation (step 3) and the candidate detail reachable from step 2.
class RoleCandidatesSheet extends ConsumerStatefulWidget {
  const RoleCandidatesSheet({super.key, required this.clubContext});

  final ClubContext clubContext;

  @override
  ConsumerState<RoleCandidatesSheet> createState() =>
      _RoleCandidatesSheetState();
}

class _RoleCandidatesSheetState extends ConsumerState<RoleCandidatesSheet> {
  _Step _step = _Step.list;
  RoleCandidate? _candidate;
  RoleCandidatesState? _loaded;
  String? _role;

  String? get _sectionName =>
      _loaded?.section?.clubTypeName ?? widget.clubContext.clubTypeName;

  void _go(_Step step) => setState(() => _step = step);

  void _back() {
    switch (_step) {
      case _Step.list:
        Navigator.of(context).maybePop();
      case _Step.roles:
        _go(_Step.list);
      case _Step.confirm || _Step.detail:
        _go(_Step.roles);
    }
  }

  void _select(RoleCandidate candidate, RoleCandidatesState state) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _candidate = candidate;
      _loaded = state;
      _role = null;
      _step = _Step.roles;
    });
  }

  String get _title => switch (_step) {
        _Step.list => 'members.role_candidates.title'.tr(),
        _Step.roles => 'members.role_candidates.roles_title'.tr(),
        _Step.confirm => 'members.role_candidates.confirm_title'.tr(),
        _Step.detail => 'members.role_candidates.detail_title'.tr(),
      };

  String? get _subtitle {
    if (_step != _Step.list) return null;
    final section = _sectionName;
    return section == null
        ? null
        : tr('members.role_candidates.subtitle',
            namedArgs: {'section': section});
  }

  Widget _stepBody() {
    final candidate = _candidate!;
    return switch (_step) {
      _Step.roles => RoleCandidateRoleStep(
          candidate: candidate,
          slots: _loaded?.slots ?? const [],
          onPick: (role) => setState(() {
            _role = role;
            _step = _Step.confirm;
          }),
          onViewDetail: () => _go(_Step.detail),
        ),
      _Step.confirm => RoleCandidateConfirmStep(
          candidate: candidate,
          role: _role!,
          clubContext: widget.clubContext,
          sectionName: _sectionName,
          onAssigned: (roleLabel) => Navigator.of(context).pop(roleLabel),
          onBackToList: () => _go(_Step.list),
        ),
      _Step.detail => RoleCandidateDetailStep(
          query: RoleCandidateDetailQuery(
            clubId: widget.clubContext.clubId,
            sectionId: widget.clubContext.sectionId,
            userId: candidate.userId,
          ),
          candidate: candidate,
        ),
      _Step.list => const SizedBox.shrink(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final media = MediaQuery.of(context);
    final available =
        media.size.height - media.viewInsets.bottom - media.padding.top - 8;
    final reduce = SacMotion.reduceMotionOf(context);
    final onList = _step == _Step.list;

    return PopScope(
      canPop: onList,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: SizedBox(
          height: available * 0.94,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: c.background,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusXL),
              ),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusXL),
              ),
              child: Column(
                children: [
                  SacSheetHeader(
                    title: _title,
                    subtitle: _subtitle,
                    showClose: true,
                    leading: onList
                        ? null
                        : SacPressable(
                            listenOnly: true,
                            child: IconButton(
                              enableFeedback: false,
                              tooltip: MaterialLocalizations.of(context)
                                  .backButtonTooltip,
                              onPressed: _back,
                              icon: HugeIcon(
                                icon: HugeIcons.strokeRoundedArrowLeft01,
                                size: 22,
                                color: c.textSecondary,
                              ),
                            ),
                          ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        // Always mounted: going back keeps search, filter and
                        // scroll position.
                        Positioned.fill(
                          child: Offstage(
                            offstage: !onList,
                            child: TickerMode(
                              enabled: onList,
                              child: RoleCandidatesListStep(
                                clubContext: widget.clubContext,
                                onSelect: _select,
                              ),
                            ),
                          ),
                        ),
                        if (!onList)
                          Positioned.fill(
                            child: ColoredBox(
                              color: c.background,
                              child: AnimatedSwitcher(
                                duration:
                                    reduce ? Duration.zero : SacMotion.standard,
                                child: KeyedSubtree(
                                  key: ValueKey(
                                    '$_step-${_candidate?.userId}',
                                  ),
                                  child: _stepBody(),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
