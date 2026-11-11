import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';

import '../../domain/entities/role_candidate.dart';
import '../providers/members_providers.dart';
import '../providers/role_candidates_providers.dart';
import '../utils/role_candidate_labels.dart';
import 'role_candidate_header.dart';

/// Step 3: summary, the «también es consejera en Conquistadores» notice (D4)
/// and the confirm button. The assignment uses the same `POST
/// /clubs/:clubId/sections/:sectionId/roles` as the rest of the app.
///
/// Errors show INSIDE the sheet (a snackbar would sit behind it). After a
/// failure that changes the slot picture (`CLUB_ROLE_SLOT_LIMIT_REACHED`, ...)
/// the lists are reloaded and the button sends the user back to the list.
class RoleCandidateConfirmStep extends ConsumerStatefulWidget {
  const RoleCandidateConfirmStep({
    super.key,
    required this.candidate,
    required this.role,
    required this.clubContext,
    this.sectionName,
    required this.onAssigned,
    required this.onBackToList,
  });

  final RoleCandidate candidate;
  final String role;
  final ClubContext clubContext;

  /// «Aventureros» / «Conquistadores»: the section that receives the role.
  final String? sectionName;

  /// Called with the translated role once the server accepted the assignment.
  final ValueChanged<String> onAssigned;
  final VoidCallback onBackToList;

  @override
  ConsumerState<RoleCandidateConfirmStep> createState() =>
      _RoleCandidateConfirmStepState();
}

class _RoleCandidateConfirmStepState
    extends ConsumerState<RoleCandidateConfirmStep> {
  bool _isSaving = false;
  String? _error;
  bool _isStale = false;

  String get _roleLabel => candidateRoleLabel(
        widget.role,
        gender: widget.candidate.gender,
      );

  Future<void> _confirm() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    final failure = await ref.read(membersNotifierProvider.notifier).assignRole(
          context: widget.clubContext,
          userId: widget.candidate.userId,
          role: widget.role,
        );
    if (!mounted) return;
    if (failure == null) {
      // The members list already reloads itself; the candidates must too.
      ref.invalidate(roleCandidatesProvider);
      widget.onAssigned(_roleLabel);
      return;
    }
    final stale = kRoleAssignStaleCodes.contains(failure.errorCode);
    if (stale) ref.invalidate(roleCandidatesProvider);
    setState(() {
      _isSaving = false;
      _isStale = stale;
      _error = roleAssignErrorMessage(failure);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final candidate = widget.candidate;
    final elsewhere = candidate.rolesElsewhere(widget.clubContext.sectionId);
    final summary = widget.sectionName == null
        ? tr('members.role_candidates.confirm_summary_no_section',
            namedArgs: {'name': candidate.name, 'role': _roleLabel})
        : tr('members.role_candidates.confirm_summary', namedArgs: {
            'name': candidate.name,
            'role': _roleLabel,
            'section': widget.sectionName!,
          });

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            children: [
              RoleCandidateHeader(candidate: candidate),
              const SizedBox(height: 20),
              Text(
                summary,
                style: TextStyle(
                  fontSize: SacFontSize.titleMedium,
                  color: c.text,
                  height: 1.35,
                ),
              ),
              for (final other in elsewhere) ...[
                const SizedBox(height: 12),
                _Notice(
                  key: ValueKey(
                      'other-section-${other.sectionId}-${other.role}'),
                  icon: HugeIcons.strokeRoundedInformationCircle,
                  background: c.infoContainer,
                  foreground: c.onInfoContainer,
                  text:
                      tr('members.role_candidates.also_holds_role', namedArgs: {
                    'role': candidateRoleLabel(other.role,
                        gender: candidate.gender),
                    'club': other.clubTypeName ??
                        'members.role_candidates.other_section'.tr(),
                  }),
                ),
              ],
              if (candidate.requirementFor(widget.role)?.isFlagged ??
                  false) ...[
                const SizedBox(height: 12),
                _Notice(
                  key: const ValueKey('requirement-notice'),
                  icon: HugeIcons.strokeRoundedAlert02,
                  background: c.warningContainer,
                  foreground: c.onWarningContainer,
                  text:
                      'members.role_candidates.credential.notice_missing'.tr(),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                _Notice(
                  key: const ValueKey('assign-error'),
                  icon: HugeIcons.strokeRoundedAlert02,
                  background: c.errorContainer,
                  foreground: c.onErrorContainer,
                  text: _error!,
                  isLive: true,
                ),
              ],
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            12 + MediaQuery.paddingOf(context).bottom,
          ),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border(top: BorderSide(color: c.border)),
          ),
          child: _isStale
              ? SacButton.outline(
                  text: 'members.role_candidates.back_to_list'.tr(),
                  icon: HugeIcons.strokeRoundedArrowLeft01,
                  onPressed: widget.onBackToList,
                )
              : SacButton.primary(
                  text: 'members.role_candidates.confirm_action'.tr(),
                  icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                  isLoading: _isSaving,
                  onPressed: _isSaving ? null : _confirm,
                ),
        ),
      ],
    );
  }
}

/// Rounded message box: info (other section) or error (server rejected).
class _Notice extends StatelessWidget {
  const _Notice({
    super.key,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.text,
    this.isLive = false,
  });

  final HugeIconData icon;
  final Color background;
  final Color foreground;
  final String text;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: isLive,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: HugeIcon(icon: icon, size: 18, color: foreground),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: SacFontSize.bodyMedium,
                    color: foreground,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
