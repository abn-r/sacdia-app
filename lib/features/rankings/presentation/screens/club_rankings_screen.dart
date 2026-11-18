import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/animations/motion_tokens.dart';
import '../../../../core/animations/staggered_list_animation.dart';
import '../../../../core/authorization/access_subject.dart';
import '../../../../core/authorization/screen_catalog.dart';
import '../../../../core/config/route_names.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_frosted_footer.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../../features/auth/domain/entities/user_entity.dart';
import '../../../../features/auth/domain/utils/authorization_utils.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../../features/members/presentation/providers/members_providers.dart';
import '../../../../providers/catalogs_provider.dart';
import '../../domain/entities/annual_ranking_progress.dart';
import '../providers/annual_ranking_progress_provider.dart';
import '../widgets/annual_pending_section.dart';
import '../widgets/annual_points_map.dart';
import '../widgets/annual_progress_hero.dart';
import '../widgets/ranking_empty_state.dart';
import '../widgets/ranking_skeleton.dart';

/// Screen id of the annual evidence folder in the screen catalog.
const String _kEvidenceFolderScreenId = 'clubs-evidence-folders-list';

class ClubRankingsScreen extends ConsumerWidget {
  const ClubRankingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authView = ref.watch(
      authNotifierProvider.select(
        (value) => (
          isLoading: value.isLoading,
          hasError: value.hasError,
          user: value.value,
        ),
      ),
    );
    final ctxAsync = ref.watch(clubContextProvider);
    final yearAsync = ref.watch(currentEcclesiasticalYearProvider);
    final c = context.sac;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar:
          SacTopBar(title: tr('rankings.annual_progress.title'), frosted: true),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => Builder(
            builder: (context) {
              if (authView.isLoading) {
                return RankingSkeleton.annualProgress();
              }
              if (authView.hasError || !_canViewAnnualProgress(authView.user)) {
                return const RankingEmptyState(
                  reason: RankingEmptyReason.unauthorized,
                );
              }

              return yearAsync.when(
                data: (year) {
                  if (year == null) {
                    return const RankingEmptyState(
                      reason: RankingEmptyReason.noData,
                    );
                  }

                  return ctxAsync.when(
                    data: (ctx) {
                      if (ctx == null) {
                        return const RankingEmptyState(
                          reason: RankingEmptyReason.unauthorized,
                        );
                      }

                      return _AnnualRankingProgressBody(
                        sectionId: ctx.sectionId,
                        yearId: year.ecclesiasticalYearId,
                        yearName: year.name,
                        canOpenFolder: canViewScreen(
                          subjectFromUser(authView.user),
                          _kEvidenceFolderScreenId,
                        ),
                      );
                    },
                    loading: () => RankingSkeleton.annualProgress(),
                    error: (_, __) => RankingEmptyState(
                      reason: RankingEmptyReason.networkError,
                      onRetry: () => ref.invalidate(clubContextProvider),
                    ),
                  );
                },
                loading: () => RankingSkeleton.annualProgress(),
                error: (_, __) => RankingEmptyState(
                  reason: RankingEmptyReason.networkError,
                  onRetry: () =>
                      ref.invalidate(currentEcclesiasticalYearProvider),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

bool _canViewAnnualProgress(UserEntity? user) {
  return canViewClubRankings(user) || canViewSectionRankings(user);
}

const _kAnnualRankingConfigNotFound = 'ANNUAL_RANKING_CONFIG_NOT_FOUND';

/// Sin configuración anual de ranking (404 del backend) no es un error de
/// red: se muestra como "aún no configurado" y sin reintento.
RankingEmptyReason annualRankingProgressErrorReason(Object error) {
  if (error is Failure && error.errorCode == _kAnnualRankingConfigNotFound) {
    return RankingEmptyReason.notConfigured;
  }
  return RankingEmptyReason.networkError;
}

class _AnnualRankingProgressBody extends ConsumerWidget {
  final int sectionId;
  final int yearId;
  final String yearName;
  final bool canOpenFolder;

  const _AnnualRankingProgressBody({
    required this.sectionId,
    required this.yearId,
    required this.yearName,
    required this.canOpenFolder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = (sectionId: sectionId, yearId: yearId);
    final progressAsync = ref.watch(annualRankingProgressProvider(params));

    return progressAsync.when(
      data: (progress) => AnnualRankingProgressContent(
        progress: progress,
        yearName: yearName,
        canOpenFolder: canOpenFolder,
        onRefresh: () async =>
            ref.invalidate(annualRankingProgressProvider(params)),
      ),
      loading: () => RankingSkeleton.annualProgress(),
      error: (error, __) => RankingEmptyState(
        reason: annualRankingProgressErrorReason(error),
        onRetry: () => ref.invalidate(annualRankingProgressProvider(params)),
      ),
    );
  }
}

class AnnualRankingProgressContent extends StatelessWidget {
  final AnnualRankingProgress progress;
  final String yearName;
  final Future<void> Function() onRefresh;

  /// Opens the annual evidence folder. Defaults to pushing its route.
  final VoidCallback? onOpenFolder;

  /// False when the user cannot open the folder: the rows stay plain and the
  /// footer action is not shown.
  final bool canOpenFolder;

  const AnnualRankingProgressContent({
    super.key,
    required this.progress,
    required this.yearName,
    required this.onRefresh,
    this.onOpenFolder,
    this.canOpenFolder = true,
  });

  @override
  Widget build(BuildContext context) {
    final VoidCallback? openFolder = canOpenFolder
        ? (onOpenFolder ?? () => context.push(RouteNames.homeEvidences))
        : null;
    final sections = <Widget>[
      AnnualProgressHero(progress: progress, yearName: yearName),
      AnnualPointsMap(progress: progress),
      AnnualPendingSection(progress: progress, onOpenFolder: openFolder),
    ];
    final footerRoom = openFolder == null ? 32.0 : SacFrostedFooter.height + 16;

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: onRefresh,
          color: SacAccent.of(context).color,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: SacTopBar.paddingBelowBar(
              context,
              EdgeInsets.fromLTRB(0, 8, 0, footerRoom),
            ),
            itemCount: sections.length,
            itemBuilder: (context, index) => StaggeredListItem(
              index: index,
              staggerDelay: SacMotion.stagger,
              duration: SacMotion.standard,
              slideOffset: 8,
              child: sections[index],
            ),
          ),
        ),
        if (openFolder != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SacFrostedFooter(
              child: SacButton.primary(
                key: const ValueKey('annual-open-folder'),
                text: tr('rankings.annual_progress.open_folder'),
                icon: HugeIcons.strokeRoundedFolder01,
                onPressed: openFolder,
              ),
            ),
          ),
      ],
    );
  }
}
