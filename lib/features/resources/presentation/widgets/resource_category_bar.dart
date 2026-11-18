import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/widgets/sac_filter_chip.dart';
import '../providers/resources_providers.dart';

/// Second, quieter chip row: categories with how many resources each holds.
///
/// Wired to [selectedResourceCategoryProvider]; tapping the selected chip
/// clears it. Counts come from [resourceFacetProvider] under the active type
/// and search, and are only shown when that look covered every match.
/// Categories come from the loaded resources (see
/// [resourceCategoryOptionsProvider]), so a 403 on `/resource-categories`
/// does not hide the bar. Hidden while there are none.
class ResourceCategoryBar extends ConsumerWidget {
  const ResourceCategoryBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(resourceCategoryOptionsProvider);
    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }

    final selected = ref.watch(selectedResourceCategoryProvider);
    final type = ref.watch(selectedResourceTypeProvider);
    final search = ref.watch(resourceSearchProvider).trim();
    final facet = ref
        .watch(resourceFacetProvider(
          ResourceFacetQuery(type: type, search: search),
        ))
        .value;
    final counts =
        (facet != null && facet.isComplete) ? facet.categoryCounts : null;

    final visible = categories
        .where((category) =>
            counts == null ||
            (counts[category.resourceCategoryId] ?? 0) > 0 ||
            category.resourceCategoryId == selected)
        .toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      padding: const EdgeInsets.only(right: 20),
      child: Row(
        children: [
          for (final category in visible)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: SacFilterChip(
                variant: SacFilterChipVariant.quiet,
                label: category.name,
                count: counts == null
                    ? null
                    : (counts[category.resourceCategoryId] ?? 0),
                selected: category.resourceCategoryId == selected,
                onTap: () {
                  ref.read(selectedResourceCategoryProvider.notifier).state =
                      category.resourceCategoryId == selected
                          ? null
                          : category.resourceCategoryId;
                },
              ),
            ),
        ],
      ),
    );
  }
}
