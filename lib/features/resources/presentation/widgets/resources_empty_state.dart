import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import '../providers/resources_providers.dart';

/// Empty library, in two flavours the user must tell apart:
///
/// - Nothing is filtered or searched: the club has no resources yet.
/// - A search or filter matched nothing: repeat what was asked, say whether
///   other types do have matches, and always give a way out.
class ResourcesEmptyState extends ConsumerWidget {
  const ResourcesEmptyState({
    super.key,
    required this.onRefresh,
    required this.onClearSearch,
  });

  /// Reloads the first page (club empty state action).
  final VoidCallback onRefresh;

  /// Clears the search box and provider.
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = ref.watch(resourceSearchProvider).trim();
    final type = ref.watch(selectedResourceTypeProvider);
    final category = ref.watch(selectedResourceCategoryProvider);

    if (search.isEmpty && type == null && category == null) {
      return SacEmptyState(
        icon: HugeIcons.strokeRoundedFolder02,
        title: 'resources.empty_club.title'.tr(),
        body: 'resources.empty_club.body'.tr(),
        actionLabel: 'resources.empty_club.action'.tr(),
        actionIcon: HugeIcons.strokeRoundedRefresh,
        actionVariant: SacButtonVariant.outline,
        onAction: onRefresh,
      );
    }

    // Matches the same query in every type (category still applied).
    final other = type == null
        ? null
        : ref.watch(resourceFacetProvider(
            ResourceFacetQuery(search: search, categoryId: category),
          ));
    final otherCount = other?.value?.total ?? 0;
    final otherLoading = other?.isLoading ?? false;
    final offerAllTypes = type != null && (otherCount > 0 || otherLoading);

    final String title;
    if (search.isNotEmpty && type != null) {
      title = 'resources.no_results.title_type'.tr(namedArgs: {
        'type': _typeName(type).toLowerCase(),
        'query': search,
      });
    } else if (search.isNotEmpty) {
      title = 'resources.no_results.title_query'.tr(namedArgs: {
        'query': search,
      });
    } else {
      title = 'resources.no_results.title_filters'.tr();
    }

    final String? body = otherCount > 0
        ? 'resources.no_results.body_other_types'
            .tr(namedArgs: {'count': '$otherCount'})
        : (otherLoading ? null : 'resources.no_results.body_none'.tr());

    final String actionLabel;
    final VoidCallback onAction;
    final HugeIconData actionIcon;
    if (offerAllTypes) {
      actionLabel = 'resources.no_results.action_all_types'.tr();
      actionIcon = HugeIcons.strokeRoundedGridView;
      onAction =
          () => ref.read(selectedResourceTypeProvider.notifier).state = null;
    } else if (type != null || category != null) {
      actionLabel = 'resources.no_results.action_clear_filters'.tr();
      actionIcon = HugeIcons.strokeRoundedFilterRemove;
      onAction = () {
        ref.read(selectedResourceTypeProvider.notifier).state = null;
        ref.read(selectedResourceCategoryProvider.notifier).state = null;
      };
    } else {
      actionLabel = 'resources.no_results.action_clear_search'.tr();
      actionIcon = HugeIcons.strokeRoundedCancelCircle;
      onAction = onClearSearch;
    }

    return SacEmptyState(
      icon: HugeIcons.strokeRoundedSearch01,
      title: title,
      body: body,
      actionLabel: actionLabel,
      actionIcon: actionIcon,
      onAction: onAction,
    );
  }

  String _typeName(String type) => switch (type) {
        'document' => 'resources.filter.document'.tr(),
        'audio' => 'resources.filter.audio'.tr(),
        'image' => 'resources.filter.image'.tr(),
        'video_link' => 'resources.filter.video'.tr(),
        'text' => 'resources.filter.text'.tr(),
        _ => type,
      };
}
